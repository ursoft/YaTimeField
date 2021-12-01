import Toybox.Application;
import Toybox.Lang;
using Toybox.System as Sys;
using Toybox.WatchUi as Ui;
import Toybox.Application.Properties;

const APP_VERSION as String = "01.12.21 #18"; //change it here (the only place)

class YaTimeFieldApp extends Application.AppBase {
    function initialize() {
        AppBase.initialize();
        storeSetting("appVersion", APP_VERSION);
        readAllSettings();
    }
    function storeSetting(name as String, value as Numeric or Boolean or String) as Void {
        try {
            if (Application has :Storage) {
                Properties.setValue(name, value);
            } else {
                AppBase.setProperty(name, value);
            }
        } catch(ex) {
            Sys.println(Lang.format("storeSetting($1$, $2$) exception: $3$", [name, value, ex.getErrorMessage()]));
        }
    }
    function readSetting(name as String, defValue as Numeric or Boolean or String) as Numeric or Boolean or String or Null {
        try {
            if (Application has :Storage) {
                var ret = Properties.getValue(name);
                return ret;
            } else {
                return AppBase.getProperty(name);
            }
        } catch(ex) {
            storeSetting(name, defValue);
            Sys.println(Lang.format("readSetting($1$) exception: $2$", [name, ex.getErrorMessage()])); 
            return defValue;
        }
    }
    // onStart() is called on application start up
    function onStart(state as Dictionary?) as Void {}
    // onStop() is called when your application is exiting
    function onStop(state as Dictionary?) as Void {}

    var m_view as YaTimeFieldView?;
    // Return the initial view of your application here
    function getInitialView() as Array<Ui.Views or Ui.InputDelegates>? {
        if (m_view == null) { m_view = new YaTimeFieldView(); }
        return [ m_view/*, new MyInputDelegate()*/ ] as Array<Ui.Views or Ui.InputDelegates>;
    }

    var m_fieldCaptionVisible as Boolean = true;
    var m_flipLandscape as Boolean = false;
    var m_forceVectorFont as Boolean = false;
    var m_antiAliasing as Boolean = true;
    var m_fieldCaption as String = "";
    var m_fieldSources as Array<Number> = [0, -1, -1, -1] as Array<Number>; //=SK_CNT
    function readAllSettings() as Void {
        m_fieldCaptionVisible = true;
        m_flipLandscape = false;
        m_forceVectorFont = false;
        m_antiAliasing = true;
        m_fieldCaption = "";
        m_fieldSources[0] = 0;
        m_fieldSources[1] = -1;
        m_fieldSources[2] = -1;
        m_fieldSources[3] = -1;
        try {
            m_fieldCaptionVisible = readSetting("fieldCaptionVisible", m_fieldCaptionVisible) as Boolean;
            m_flipLandscape = readSetting("flipLandscape", m_flipLandscape) as Boolean;
            m_forceVectorFont = readSetting("forceVectorFont", m_forceVectorFont) as Boolean;
            m_antiAliasing = readSetting("antiAliasing", m_antiAliasing) as Boolean;
            m_fieldCaption = readSetting("fieldCaption", m_fieldCaption) as String;
            m_fieldSources[0] = readSetting("fieldSource1", m_fieldSources[0]) as Number;
            m_fieldSources[1] = readSetting("fieldSource2", m_fieldSources[1]) as Number;
            m_fieldSources[2] = readSetting("fieldSource3", m_fieldSources[2]) as Number;
            m_fieldSources[3] = readSetting("fieldSource4", m_fieldSources[3]) as Number;
        } catch(ex) {
            Sys.println(Lang.format("readAllSettings exception: $1$", [ex.getErrorMessage()])); 
        }
    }
    function onSettingsChanged() as Void {
        AppBase.onSettingsChanged();
        readAllSettings();
        if(m_view != null) {
            m_view.rebuildSources();
        }
        Ui.requestUpdate();
    }
    function getSettingsView() as Array<Ui.Views or Ui.InputDelegates>? {
        return [new MySettingsMenu(), new MySettingsMenuDelegate()] as Array<Ui.Views or Ui.InputDelegates>;
    }
}
function FieldSourceToString(fs as Number) as String {
    switch (fs) {
        case -1: return Ui.loadResource(Rez.Strings.noFieldSource) as String;
        case 0:  return Ui.loadResource(Rez.Strings.timerTime) as String;
        case 1:  return Ui.loadResource(Rez.Strings.clockTime) as String;
        case 2:  return Ui.loadResource(Rez.Strings.elapsedTime) as String;
        case 3:  return Ui.loadResource(Rez.Strings.timeLeftFinSettings) as String;
        case 4:  return Ui.loadResource(Rez.Strings.timeLeftNxtSettings) as String;
        case 5:  return Ui.loadResource(Rez.Strings.lapTime) as String;
        case 6:  return Ui.loadResource(Rez.Strings.avgLapTime) as String;
    }
}
class MySettingsMenu extends Ui.Menu2 {
    function initialize() {
        Menu2.initialize(null);
        Menu2.setTitle((Ui.loadResource(Rez.Strings.AppName) as String) + " v" + APP_VERSION);
        var app = $.getApp();
        Menu2.addItem(new Ui.ToggleMenuItem("fieldCaptionVisible", Ui.loadResource(Rez.Strings.fieldCaptionVisibleTitle) as String, "fieldCaptionVisible", app.m_fieldCaptionVisible, null));
        Menu2.addItem(new Ui.MenuItem(app.m_fieldCaption, Ui.loadResource(Rez.Strings.fieldCaptionTitle) as String, "fieldCaption", null));
        Menu2.addItem(new Ui.ToggleMenuItem("flipLandscape", Ui.loadResource(Rez.Strings.flipLandscapeTitle) as String, "flipLandscape", app.m_flipLandscape, null));
        Menu2.addItem(new Ui.ToggleMenuItem("forceVectorFont", Ui.loadResource(Rez.Strings.forceVectorFontTitle) as String, "forceVectorFont", app.m_forceVectorFont, null));
        Menu2.addItem(new Ui.ToggleMenuItem("antiAliasing", Ui.loadResource(Rez.Strings.antiAliasingTitle) as String, "antiAliasing", app.m_antiAliasing, null));        
        Menu2.addItem(new Ui.MenuItem(Ui.loadResource(Rez.Strings.fieldSourceTitle) as String, FieldSourceToString(app.m_fieldSources[0]), "0", null));
        Menu2.addItem(new Ui.MenuItem(Ui.loadResource(Rez.Strings.fieldSourceTitle) as String, FieldSourceToString(app.m_fieldSources[1]), "1", null));
        Menu2.addItem(new Ui.MenuItem(Ui.loadResource(Rez.Strings.fieldSourceTitle) as String, FieldSourceToString(app.m_fieldSources[2]), "2", null));
        Menu2.addItem(new Ui.MenuItem(Ui.loadResource(Rez.Strings.fieldSourceTitle) as String, FieldSourceToString(app.m_fieldSources[3]), "3", null));
    }    
}
class MyTextPickerDelegate extends Ui.TextPickerDelegate {
    var m_sender as Ui.MenuItem;
    function initialize(sender as Ui.MenuItem) {
        TextPickerDelegate.initialize();
        m_sender = sender;
    }
    function onTextEntered(text as String, changed as Boolean) as Boolean {
        //Sys.println(Lang.format("onTextEntered($1$, $2$)", [text, changed])); 
        if (changed) {
            $.getApp().m_fieldCaption = text;
            m_sender.setLabel(text);
        }
        return true;
    }
}
class MySourceSettingsMenu extends Ui.Menu2 {
    function initialize(idx as Number) {
        Menu2.initialize(null);
        Menu2.setTitle((Ui.loadResource(Rez.Strings.fieldSourceTitle) as String) + " #" + (idx + 1).toString());
        var app = $.getApp();
        for (var i = -1; i <= 6; i++) {
            Menu2.addItem(new Ui.ToggleMenuItem(FieldSourceToString(i), null, i, app.m_fieldSources[idx] == i, null));
        }
    }    
}
class MySourceSettingsMenuDelegate extends Ui.Menu2InputDelegate {
    var m_idx as Number;
    var m_item as Ui.MenuItem;
    function initialize(idx as Number, item as Ui.MenuItem) {
        Menu2InputDelegate.initialize();
        m_idx = idx;
        m_item = item;
    }
    function onSelect(item as Ui.MenuItem) as Void {
        var id = (item.getId() as String).toNumber() as Number;
        var app = $.getApp();
        if (app.m_fieldSources[m_idx] != id) {
            app.m_fieldSources[m_idx] = id;
            m_item.setSubLabel(FieldSourceToString(id));
            app.storeSetting(Lang.format("fieldSource$1$", [m_idx + 1]), app.m_fieldSources[m_idx]);
            app.onSettingsChanged();
        }
        Ui.popView(Ui.SLIDE_IMMEDIATE);
    }
    function onBack() as Void {
        Ui.popView(Ui.SLIDE_IMMEDIATE);
    }
}
class MySettingsMenuDelegate extends Ui.Menu2InputDelegate {
    function initialize() {
        Menu2InputDelegate.initialize();
    }
    function onSelect(item as Ui.MenuItem) as Void {
        var id = item.getId() as String;
        var app = $.getApp();
        switch (id) {
            case "fieldCaptionVisible":
                app.m_fieldCaptionVisible = !app.m_fieldCaptionVisible;
                app.storeSetting(id, app.m_fieldCaptionVisible);
                break;
            case "flipLandscape":
                app.m_flipLandscape = !app.m_flipLandscape;
                app.storeSetting(id, app.m_flipLandscape);
                break;
            case "forceVectorFont":
                app.m_forceVectorFont = !app.m_forceVectorFont;
                app.storeSetting(id, app.m_forceVectorFont);
                break;
            case "antiAliasing":
                app.m_antiAliasing = !app.m_antiAliasing;
                app.storeSetting(id, app.m_antiAliasing);
                break;
            case "fieldCaption":
                Ui.pushView(new Ui.TextPicker(app.m_fieldCaption), new MyTextPickerDelegate(item), Ui.SLIDE_DOWN);
                break;
            default:
                Ui.pushView(new MySourceSettingsMenu(id.toNumber() as Number), new MySourceSettingsMenuDelegate(id.toNumber() as Number, item), Ui.SLIDE_DOWN);
                break;
        }
    }
    function onBack() as Void {
        Ui.popView(Ui.SLIDE_IMMEDIATE);
    }
}
function getApp() as YaTimeFieldApp {
    return Application.getApp() as YaTimeFieldApp;
}
