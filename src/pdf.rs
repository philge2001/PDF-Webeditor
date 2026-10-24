//! Rendern mit PDFium (pdfium.wasm über pdfium-render).
//!
//! W0: PDFium läuft im Hauptthread des Browsers. Später (W2) wandert es in einen Web Worker,
//! damit große Seiten die Oberfläche nicht kurz anhalten.

use pdfium_render::prelude::*;

/// Ein gerendertes Seitenbild (RGBA, 8 Bit je Kanal).
pub struct RenderedPage {
    pub width: usize,
    pub height: usize,
    pub rgba: Vec<u8>,
}

pub struct Renderer {
    /// `&'static`, weil `PdfDocument<'a>` sich `Pdfium` ausleiht: Mit einem dauerhaft
    /// lebenden `Pdfium` (einmal beim Start angelegt, `Box::leak`) darf das Dokument
    /// ohne Lifetime-Akrobatik in der App-Struktur liegen.
    pdfium: &'static Pdfium,
    document: Option<PdfDocument<'static>>,
}

impl Renderer {
    /// Bindet sich an das pdfium.wasm, das `web/index.html` vorher geladen hat.
    pub fn new() -> Result<Self, String> {
        let bindings =
            Pdfium::bind_to_system_library().map_err(|e| format!("PDFium nicht verfügbar: {e}"))?;
        let pdfium: &'static Pdfium = Box::leak(Box::new(Pdfium::new(bindings)));
        Ok(Self {
            pdfium,
            document: None,
        })
    }

    /// Lädt ein Dokument (ersetzt das vorige) und liefert die Seitenzahl.
    pub fn load(&mut self, bytes: Vec<u8>) -> Result<usize, String> {
        // Erst das alte Dokument schließen, damit PDFium den Speicher freigibt.
        self.document = None;
        let doc = self
            .pdfium
            .load_pdf_from_byte_vec(bytes, None)
            .map_err(|e| format!("PDFium kann die Datei nicht öffnen: {e}"))?;
        let count = doc.pages().len() as usize;
        self.document = Some(doc);
        Ok(count)
    }

    /// Rendert Seite `index` mit der Breite `width_px` (Höhe ergibt sich aus dem Seitenformat).
    pub fn render(&self, index: usize, width_px: u32) -> Result<RenderedPage, String> {
        let doc = self.document.as_ref().ok_or("kein Dokument geladen")?;
        let page = doc
            .pages()
            .get(index as PdfPageIndex)
            .map_err(|e| format!("Seite {}: {e}", index + 1))?;
        let config = PdfRenderConfig::new()
            .set_target_width(width_px as Pixels)
            .render_form_data(true);
        let bitmap = page
            .render_with_config(&config)
            .map_err(|e| format!("Rendern fehlgeschlagen: {e}"))?;
        Ok(RenderedPage {
            width: bitmap.width() as usize,
            height: bitmap.height() as usize,
            rgba: bitmap.as_rgba_bytes(),
        })
    }
}
