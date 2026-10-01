.pragma library

// Qt locale owns translated day/month names and date formatting.
function format(date, language) {
    return Qt.locale(language).toString(date, qsTranslate("Pedro", "clock.pattern"));
}
