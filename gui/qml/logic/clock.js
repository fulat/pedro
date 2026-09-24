.pragma library

function format(date) {
    const days = ["Dom", "Lun", "Mar", "Mié", "Jue", "Vie", "Sáb"]
    const months = ["Ene", "Feb", "Mar", "Abr", "May", "Jun",
                    "Jul", "Ago", "Sep", "Oct", "Nov", "Dic"]
    return days[date.getDay()] + ", " + date.getDate() + " de "
            + months[date.getMonth()] + "   " + Qt.formatTime(date, "HH:mm")
}
