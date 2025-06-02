// Arquivo: ags/widget/settings/WallpaperPage.ts
// ESTE É O SEU CÓDIGO V23 que você forneceu como base funcional
import Widget from "resource:///com/github/Aylur/ags/widget.js";
import * as _Utils from "resource:///com/github/Aylur/ags/utils.js";
import GLib from "gi://GLib";
import Gdk from "gi://Gdk";
import wallpaper from "service/wallpaper";
import App from "resource:///com/github/Aylur/ags/app.js";

const hyprland = await Service.import("hyprland");

const WALLPAPER_DIR = GLib.get_home_dir() + "/.wallpapers";
const LOG_PREFIX = "[WP_PAGE_V23_ORIGINAL]"; // Novo prefixo para esta versão

async function getWallpapers(): Promise<string[]> {
    if (!GLib.file_test(WALLPAPER_DIR, GLib.FileTest.IS_DIR)) {
        console.error(`${LOG_PREFIX} getWallpapers: Diretório NÃO EXISTE: ${WALLPAPER_DIR}`);
        return [];
    }
    const command = ['find', WALLPAPER_DIR, '-type', 'f', '(', '-iname', '*.jpg', '-o', '-iname', '*.jpeg', '-o', '-iname', '*.png', '-o', '-iname', '*.gif', ')'];
    try {
        const rawOutput = await _Utils.execAsync(command);
        if (typeof rawOutput !== 'string') {
            console.error(`${LOG_PREFIX} getWallpapers: Saída de execAsync não é string.`);
            return [];
        }
        const files = rawOutput.split('\n').filter(f => f.trim() !== "");
        // console.log(`${LOG_PREFIX} getWallpapers: ${files.length} arquivos encontrados.`);
        return files;
    } catch (error: any) {
        console.error(`${LOG_PREFIX} getWallpapers: ERRO execAsync: ${error?.message || JSON.stringify(error)}`);
        return [];
    }
}

const ApplyToMonitorMenu = (filePath: string) => {
    const fnLogPrefix = `${LOG_PREFIX} ApplyToMonitorMenu`;
    const menuItems: ReturnType<typeof Widget.MenuItem>[] = [];
    const monitors = hyprland.monitors;
    const resizeOption = { label_suffix: "(ajustar/fit)", resize_mode: "fit" };

    if (monitors.length === 0) {
        menuItems.push(Widget.MenuItem({ child: Widget.Label("Nenhum monitor encontrado") }));
    } else {
        for (const monitor of monitors) {
            const connectorName = monitor.name; 
            menuItems.push(Widget.MenuItem({
                child: Widget.Label(`Aplicar em ${connectorName} ${resizeOption.label_suffix}`),
                on_activate: () => { 
                    GLib.idle_add(GLib.PRIORITY_DEFAULT_IDLE, () => {
                        const async_action = async () => {
                            const cmd = ['swww', 'img', '--outputs', connectorName, '--resize', resizeOption.resize_mode, '--transition-type', 'any', filePath];
                            try {
                                await _Utils.subprocess(cmd); 
                                console.log(`${fnLogPrefix} Wallpaper ${filePath} (${resizeOption.resize_mode}) aplicado a ${connectorName} (idle).`);
                            } catch (err: any) {
                                console.error(`${fnLogPrefix} Falha ao aplicar (idle) a ${connectorName}: ${err?.message || err}`);
                            }
                        };
                        async_action().catch(e => console.error(`${fnLogPrefix} Erro não capturado (idle) para ${connectorName}: ${e}`));
                        return GLib.SOURCE_REMOVE; 
                    });
                },
            }));
        }
    }
    menuItems.push(Widget.MenuItem({
        child: Widget.Label("Aplicar a Todos (ajustar/fit)"),
        on_activate: () => { 
            GLib.idle_add(GLib.PRIORITY_DEFAULT_IDLE, () => {
                const async_action = async () => {
                    try {
                        if (monitors.length > 0) {
                            for (const monitor of monitors) {
                                const cmd = ['swww', 'img', '--outputs', monitor.name, '--resize', 'fit', '--transition-type', 'any', filePath];
                                await _Utils.subprocess(cmd);
                            }
                            console.log(`${fnLogPrefix} Wallpaper ${filePath} (fit) aplicado a todos (idle).`);
                        } else {
                            const cmd = ['swww', 'img', '--resize', 'fit', '--transition-type', 'any', filePath];
                            await _Utils.subprocess(cmd);
                            console.log(`${fnLogPrefix} Wallpaper ${filePath} (fit) aplicado globalmente (idle).`);
                        }
                    } catch (err: any) {
                        console.error(`${fnLogPrefix} Falha ao aplicar a todos (idle): ${err?.message || err}`);
                    }
                };
                async_action().catch(e => console.error(`${fnLogPrefix} Erro não capturado (idle) para Aplicar a Todos: ${e}`));
                return GLib.SOURCE_REMOVE;
            });
        },
    }));
    const menu = Widget.Menu({ class_name: "wallpaper-monitor-menu", children: menuItems });
    menu.popup_at_pointer(null);
};

const WallpaperItem = (filePath: string) => {
    return Widget.Button({
        class_name: "wallpaper-item", 
        tooltip_text: filePath.substring(filePath.lastIndexOf('/') + 1),
        css: `
            background-image: url("file://${filePath.replace(/'/g, "%27").replace(/ /g, "%20")}");
            background-size: cover; 
            background-repeat: no-repeat;
            background-position: center;
            
            min-width: 150px;
            min-height: 85px; 
            
            border-radius: 8px; 
            margin: 0px; 
            padding: 0px; 
            border: 1px solid rgba(100,100,100,0.1); 
            
            outline: none; 
            box-shadow: none; 
        `,
        on_clicked: () => { ApplyToMonitorMenu(filePath); },
    });
};

const WallpaperGrid = (wallpapers: string[]) => {
    if (wallpapers.length === 0) {
        return Widget.Box({
            vexpand: true, hexpand: true, hpack: "center", vpack: "center",
            child: Widget.Label("Nenhum wallpaper encontrado ou processado.\nVerifique os logs '" + LOG_PREFIX + "' no console.")
        });
    }
    const flowbox = Widget.FlowBox({
        class_name: "wallpaper-grid",
        vexpand: false, hexpand: true, hpack: "fill", vpack: "start", 
        min_children_per_line: 3, 
        max_children_per_line: 5, 
        row_spacing: 8,          
        column_spacing: 8,       
        css: "padding: 8px;",    
    });
    for (const wallpaperPath of wallpapers) {
        flowbox.add(WallpaperItem(wallpaperPath));
    }
    return flowbox; 
};

export default () => {
    const fnName = `${LOG_PREFIX}_export_default`;
    let isMounted = false; 
    let wallpapersLoadedInitially = false; // Flag original do seu V23

    const placeholderLabel = Widget.Label("Carregando papéis de parede...");
    const contentBox = Widget.Box({
        vertical: true, hexpand: true, vexpand: true,
        hpack: "fill", vpack: "fill",
        child: placeholderLabel,
    });

    const scrollable = Widget.Scrollable({
        hscroll: "never", vscroll: "automatic",
        css: "min-width: 660px; min-height: 480px; padding: 5px;", 
        child: contentBox,
    });

    const mainPageBox = Widget.Box({
        class_name: "wallpaper-settings-page",
        css: "padding: 15px;",
        vertical: true,
        spacing: 10,
        // Lógica de setup do seu V23 original
        setup: self => {
            self.connect("map", () => {
                isMounted = true;
                if (!wallpapersLoadedInitially) { // Carrega apenas uma vez
                    wallpapersLoadedInitially = true; 
                    getWallpapers().then(wallpapers => {
                        if (!isMounted || !contentBox.get_parent() || !mainPageBox.get_parent()) return;
                        contentBox.child = WallpaperGrid(wallpapers);
                    }).catch(e => {
                        if (!isMounted) return;
                        // Mudado o texto do erro para refletir que esta é a V23 original
                        console.error(`${fnName} .catch() CRÍTICO (V23_ORIGINAL) de getWallpapers:`, e);
                        placeholderLabel.label = `Falha crítica (V23_ORIGINAL). Ver console: ${e?.message || e}`;
                        contentBox.child = placeholderLabel; 
                    });
                }
            });
            self.connect("unmap", () => { 
                isMounted = false; 
                // NENHUMA LÓGICA DE LIMPEZA AQUI, como no seu V23 original
            });
            self.connect("destroy", () => { 
                isMounted = false; 
                // NENHUMA LÓGICA DE LIMPEZA AQUI, como no seu V23 original
            });
        },
        children: [
            Widget.Label({
                label: "Seleção de Papel de Parede",
                hpack: "start", class_name: "title",
                css: "font-size: 1.3em; margin-bottom: 10px;",
            }),
            scrollable,
        ],
    });
    return mainPageBox;
};
