.pragma library

// Qt locale owns translated day/month names and date formatting.
function format(date, language) {
    const locale = Qt.locale(language);
    const formatted = locale.toString(date, qsTranslate("Pedro", "clock.pattern"));
    const month = locale.toString(date, "MMM");
    const capitalizedMonth = month.charAt(0).toLocaleUpperCase() + month.slice(1);
    const capitalizedDate = formatted.replace(month, capitalizedMonth);
    return capitalizedDate.charAt(0).toLocaleUpperCase() + capitalizedDate.slice(1);
}

// Defaults to twelve-hour time; callers may supply a future user preference.
function time(date, language, twelveHour) {
    const pattern = twelveHour === false ? "HH:mm" : "h:mm AP";
    return Qt.locale(language).toString(date, pattern);
}
