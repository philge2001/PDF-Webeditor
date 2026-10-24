//! Oberfläche des Machbarkeitstests (egui im Browser).

use std::cell::RefCell;
use std::rc::Rc;

use eframe::egui;
use pdftool_core::Document;

use crate::browser;
use crate::pdf::Renderer;

/// Eine vom Browser gelieferte Datei (Dateidialog oder Drag & Drop).
struct IncomingFile {
    name: String,
    bytes: Vec<u8>,
}

/// Messwerte zum Dokument – Zweck des Machbarkeitstests.
#[derive(Default)]
struct Stats {
    core_open_ms: f64,
    pdfium_open_ms: f64,
    pdfium_pages: usize,
    last_render_ms: f64,
    last_render_px: (usize, usize),
}

struct OpenDoc {
    name: String,
    doc: Document,
    page: usize,
    /// Textur der aktuellen Seite samt (Seite, Breite in Pixeln), für die sie gerendert wurde.
    texture: Option<((usize, u32), egui::TextureHandle)>,
    stats: Stats,
}

pub struct WebApp {
    renderer: Result<Renderer, String>,
    doc: Option<OpenDoc>,
    /// Briefkasten für asynchron gelesene Dateien. `Rc<RefCell<…>>`, weil der Dateidialog in einer
    /// eigenen Future läuft (`spawn_local`) und das Ergebnis später hier abholt – beide Seiten
    /// teilen sich denselben Speicherplatz, ein Thread genügt (deshalb kein `Arc<Mutex<…>>`).
    inbox: Rc<RefCell<Option<IncomingFile>>>,
    zoom: f32,
    message: Option<String>,
}

impl WebApp {
    pub fn new(cc: &eframe::CreationContext<'_>) -> Self {
        cc.egui_ctx.set_theme(egui::Theme::Light);
        Self {
            renderer: Renderer::new(),
            doc: None,
            inbox: Rc::new(RefCell::new(None)),
            zoom: 1.0,
            message: None,
        }
    }

    fn pick_file(&self, ctx: &egui::Context) {
        let inbox = Rc::clone(&self.inbox);
        let ctx = ctx.clone();
        wasm_bindgen_futures::spawn_local(async move {
            let Some(file) = rfd::AsyncFileDialog::new()
                .add_filter("PDF", &["pdf"])
                .pick_file()
                .await
            else {
                return; // abgebrochen
            };
            let bytes = file.read().await;
            *inbox.borrow_mut() = Some(IncomingFile {
                name: file.file_name(),
                bytes,
            });
            ctx.request_repaint();
        });
    }

    /// Drag & Drop: Im Browser gibt es keinen Pfad, die Bytes kommen asynchron aus dem `File`.
    fn handle_dropped_files(&mut self, ctx: &egui::Context) {
        let dropped = ctx.input(|i| i.raw.dropped_files.first().cloned());
        let Some(file) = dropped else {
            return;
        };
        let name = file
            .path()
            .file_name()
            .map(|n| n.to_string_lossy().into_owned())
            .unwrap_or_else(|| "Dokument.pdf".into());
        let inbox = Rc::clone(&self.inbox);
        let ctx = ctx.clone();
        // `file` ist ein `Arc` und wird in die Future verschoben – sie lebt, bis gelesen ist.
        wasm_bindgen_futures::spawn_local(async move {
            match file.bytes_async().await {
                Ok(bytes) => *inbox.borrow_mut() = Some(IncomingFile { name, bytes }),
                Err(e) => log::error!("Datei {name} nicht lesbar: {e}"),
            }
            ctx.request_repaint();
        });
    }

    fn open(&mut self, file: IncomingFile) {
        let renderer = match &mut self.renderer {
            Ok(r) => r,
            Err(e) => {
                self.message = Some(e.clone());
                return;
            }
        };

        let t0 = browser::now_ms();
        let doc = match Document::from_bytes(file.bytes.clone()) {
            Ok(d) => d,
            Err(e) => {
                self.message = Some(format!("{}: {e}", file.name));
                return;
            }
        };
        let t1 = browser::now_ms();
        let pdfium_pages = match renderer.load(file.bytes) {
            Ok(n) => n,
            Err(e) => {
                self.message = Some(e);
                return;
            }
        };
        let t2 = browser::now_ms();

        self.message = None;
        self.doc = Some(OpenDoc {
            name: file.name,
            doc,
            page: 0,
            texture: None,
            stats: Stats {
                core_open_ms: t1 - t0,
                pdfium_open_ms: t2 - t1,
                pdfium_pages,
                ..Stats::default()
            },
        });
    }

    fn top_bar(&mut self, ui: &mut egui::Ui) {
        ui.horizontal_wrapped(|ui| {
            ui.strong("PDF Webeditor");
            ui.separator();
            if ui.button("PDF öffnen…").clicked() {
                self.pick_file(ui.ctx());
            }
            if ui.button("Beispiel-PDF").clicked() {
                self.open(IncomingFile {
                    name: "beispiel.pdf".into(),
                    bytes: include_bytes!("../assets/beispiel.pdf").to_vec(),
                });
            }
            let Some(doc) = &mut self.doc else {
                ui.label("… oder eine PDF ins Fenster ziehen.");
                return;
            };
            ui.separator();
            let count = doc.doc.page_count();
            if ui
                .add_enabled(doc.page > 0, egui::Button::new("◀"))
                .clicked()
            {
                doc.page -= 1;
            }
            ui.label(format!("Seite {} / {count}", doc.page + 1));
            if ui
                .add_enabled(doc.page + 1 < count, egui::Button::new("▶"))
                .clicked()
            {
                doc.page += 1;
            }
            ui.separator();
            ui.add(
                egui::Slider::new(&mut self.zoom, 0.25..=4.0)
                    .logarithmic(true)
                    .text("Zoom")
                    .custom_formatter(|v, _| format!("{:.0} %", v * 100.0)),
            );
            ui.separator();
            if ui.button("Notiz einfügen").clicked() {
                add_note(doc);
            }
            let dirty = doc.doc.is_dirty();
            if ui
                .add_enabled(dirty, egui::Button::new("Speichern (Download)"))
                .on_disabled_hover_text("Keine Änderungen")
                .clicked()
            {
                self.save_download();
            }
        });
    }

    /// Speichert inkrementell (pdftool-core), bietet die Datei als Download an und öffnet
    /// das Ergebnis neu – so zeigt PDFium die gespeicherte Fassung.
    fn save_download(&mut self) {
        let Some(doc) = &self.doc else {
            return;
        };
        let name = doc.name.clone();
        let page = doc.page;
        let result = doc
            .doc
            .to_bytes()
            .map_err(|e| format!("Speichern fehlgeschlagen: {e}"))
            .and_then(|bytes| {
                browser::download(&name, &bytes)
                    .map_err(|e| format!("Download fehlgeschlagen: {e:?}"))?;
                Ok(bytes)
            });
        match result {
            Ok(bytes) => {
                self.open(IncomingFile { name, bytes });
                // Nach dem Neuladen auf derselben Seite bleiben.
                if let Some(doc) = &mut self.doc {
                    doc.page = page.min(doc.doc.page_count().saturating_sub(1));
                }
            }
            Err(e) => self.message = Some(e),
        }
    }

    fn info_panel(ui: &mut egui::Ui, doc: &OpenDoc) {
        let s = &doc.stats;
        ui.heading("Machbarkeitstest");
        ui.label(egui::RichText::new(&doc.name).strong());
        egui::Grid::new("stats").num_columns(2).show(ui, |ui| {
            ui.label("Seiten (pdftool-core)");
            ui.label(doc.doc.page_count().to_string());
            ui.end_row();
            ui.label("Seiten (PDFium)");
            ui.label(s.pdfium_pages.to_string());
            ui.end_row();
            ui.label("Annotationen (core)");
            ui.label(doc.doc.annotations().iter().count().to_string());
            ui.end_row();
            ui.label("Formularfelder (core)");
            ui.label(doc.doc.forms().iter().count().to_string());
            ui.end_row();
            if let Ok(page) = doc.doc.page(doc.page) {
                let (w, h) = page.display_size();
                ui.label("Seitengröße");
                ui.label(format!("{w:.0} × {h:.0} pt"));
                ui.end_row();
            }
            ui.label("Öffnen core");
            ui.label(format!("{:.1} ms", s.core_open_ms));
            ui.end_row();
            ui.label("Öffnen PDFium");
            ui.label(format!("{:.1} ms", s.pdfium_open_ms));
            ui.end_row();
            ui.label("Letztes Rendern");
            ui.label(format!(
                "{:.1} ms ({} × {} px)",
                s.last_render_ms, s.last_render_px.0, s.last_render_px.1
            ));
            ui.end_row();
        });
    }

    fn page_view(&mut self, ui: &mut egui::Ui) {
        let (Some(doc), Ok(renderer)) = (&mut self.doc, &self.renderer) else {
            return;
        };
        let Ok(info) = doc.doc.page(doc.page) else {
            return;
        };
        // Breite in echten Bildschirmpixeln (Retina: pixels_per_point = 2), damit es scharf bleibt.
        let (w_pt, _) = info.display_size();
        let width_points = w_pt * self.zoom;
        let width_px = (width_points * ui.ctx().pixels_per_point())
            .round()
            .max(1.0) as u32;
        let key = (doc.page, width_px);

        if doc.texture.as_ref().map(|(k, _)| *k) != Some(key) {
            let t0 = browser::now_ms();
            match renderer.render(doc.page, width_px) {
                Ok(img) => {
                    doc.stats.last_render_ms = browser::now_ms() - t0;
                    doc.stats.last_render_px = (img.width, img.height);
                    let image = egui::ColorImage::from_rgba_unmultiplied(
                        [img.width, img.height],
                        &img.rgba,
                    );
                    let tex = ui
                        .ctx()
                        .load_texture("page", image, egui::TextureOptions::LINEAR);
                    doc.texture = Some((key, tex));
                }
                Err(e) => {
                    self.message = Some(e);
                    return;
                }
            }
        }

        if let Some((_, tex)) = &doc.texture {
            let size = tex.size_vec2() / ui.ctx().pixels_per_point();
            egui::ScrollArea::both().show(ui, |ui| {
                ui.vertical_centered(|ui| {
                    ui.add(egui::Image::new((tex.id(), size)));
                });
            });
        }
    }
}

/// Fügt eine Notiz in der Mitte der aktuellen Seite ein (über ein `Command` → Undo-fähig).
fn add_note(doc: &mut OpenDoc) {
    use pdftool_core::geometry::{Color, Point};
    use pdftool_core::{AddAnnotation, AnnotKind, Annotation};

    let Ok(info) = doc.doc.page(doc.page) else {
        return;
    };
    let b = info.crop_box;
    let pos = Point::new((b.x0 + b.x1) / 2.0, (b.y0 + b.y1) / 2.0);
    let mut a = Annotation::new(doc.page, AnnotKind::Note { pos }, Color::YELLOW);
    a.id = doc.doc.allocate_annotation_id();
    a.author = "PDF Webeditor".into();
    a.contents = "Notiz aus dem Browser".into();
    // Seit W1 funktioniert die Systemzeit von core auch im Browser (web-time); /NM vergibt
    // core beim Speichern selbst.
    a.modified = pdftool_core::date::pdf_date_now();
    if let Err(e) = doc.doc.execute(Box::new(AddAnnotation::new(a))) {
        log::error!("Notiz einfügen fehlgeschlagen: {e}");
    }
}

impl eframe::App for WebApp {
    fn ui(&mut self, ui: &mut egui::Ui, _frame: &mut eframe::Frame) {
        let ctx = ui.ctx().clone();
        // Ergebnis des Dateidialogs bzw. von Drag & Drop abholen (siehe `receive`).
        let incoming = self.inbox.borrow_mut().take();
        if let Some(file) = incoming {
            self.open(file);
        }
        self.handle_dropped_files(&ctx);

        egui::Panel::top("top").show(ui, |ui| self.top_bar(ui));

        if let Some(doc) = &self.doc {
            egui::Panel::right("info")
                .default_size(260.0)
                .show(ui, |ui| Self::info_panel(ui, doc));
        }

        egui::CentralPanel::default().show(ui, |ui| {
            if let Some(msg) = &self.message {
                ui.colored_label(egui::Color32::DARK_RED, msg);
            }
            if let Err(e) = &self.renderer {
                ui.colored_label(egui::Color32::DARK_RED, e);
            }
            if self.doc.is_some() {
                self.page_view(ui);
            } else {
                ui.centered_and_justified(|ui| {
                    ui.label(
                        "PDF öffnen oder hierher ziehen – die Datei verlässt den Browser nicht.",
                    );
                });
            }
        });
    }
}
