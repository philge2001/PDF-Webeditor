//! Kleine Helfer für Browser-Funktionen (Zeitmessung, Download).

use wasm_bindgen::JsValue;

/// Millisekunden seit dem Laden der Seite (hochauflösend, für Zeitmessungen).
///
/// `std::time::Instant` gibt es in `wasm32-unknown-unknown` nicht (Panic), deshalb `performance.now()`.
pub fn now_ms() -> f64 {
    web_sys::window()
        .and_then(|w| w.performance())
        .map(|p| p.now())
        .unwrap_or(0.0)
}

/// Sekunden seit 1970 (für PDF-Datumsangaben); ersetzt `SystemTime::now()`.
pub fn unix_secs() -> i64 {
    (js_sys::Date::now() / 1000.0) as i64
}

/// Bietet `bytes` als Datei-Download an (Blob-URL + unsichtbarer Link).
pub fn download(file_name: &str, bytes: &[u8]) -> Result<(), JsValue> {
    use wasm_bindgen::JsCast;

    // Die Bytes werden in ein JS-Uint8Array kopiert; daraus entsteht ein Blob.
    let array = js_sys::Uint8Array::from(bytes);
    let parts = js_sys::Array::of1(&array);
    let options = web_sys::BlobPropertyBag::new();
    options.set_type("application/pdf");
    let blob = web_sys::Blob::new_with_u8_array_sequence_and_options(&parts, &options)?;
    let url = web_sys::Url::create_object_url_with_blob(&blob)?;

    let document = web_sys::window()
        .and_then(|w| w.document())
        .ok_or_else(|| JsValue::from_str("kein Dokument"))?;
    let link = document
        .create_element("a")?
        .dyn_into::<web_sys::HtmlAnchorElement>()?;
    link.set_href(&url);
    link.set_download(file_name);
    link.click();
    web_sys::Url::revoke_object_url(&url)?;
    Ok(())
}
