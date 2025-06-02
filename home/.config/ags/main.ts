import "lib/session"
import "style/style"
import init from "lib/init"
import options from "options"
import Bar from "widget/bar/Bar"
import Launcher from "widget/launcher/Launcher"
import NotificationPopups from "widget/notifications/NotificationPopups"
import OSD from "widget/osd/OSD"
import Overview from "widget/overview/Overview"
import PowerMenu from "widget/powermenu/PowerMenu"
import ScreenCorners from "widget/bar/ScreenCorners"
import SettingsDialog from "widget/settings/SettingsDialog"
import Verification from "widget/powermenu/Verification"
import { forMonitors } from "lib/utils" // Mantenha esta importação
import { setupQuickSettings } from "widget/quicksettings/QuickSettings"
import { setupDateMenu } from "widget/datemenu/DateMenu"

App.config({
    onConfigParsed: () => {
        setupQuickSettings()
        setupDateMenu()
        init()
    },
    closeWindowDelay: {
        "launcher": options.transition.value,
        "overview": options.transition.value,
        "quicksettings": options.transition.value,
        "datemenu": options.transition.value,
    },
    windows: () => [
        Bar(0), // MODIFICADO: Barra apenas para o monitor 0
        ...forMonitors(NotificationPopups), // MANTIDO: Para todos os monitores
        ...forMonitors(ScreenCorners),   // MANTIDO: Para todos os monitores
        ...forMonitors(OSD),             // MANTIDO: Para todos os monitores
        Launcher(),
        Overview(),
        PowerMenu(),
        SettingsDialog(),
        Verification(),
    ],
})