import Toybox.Application;
import Toybox.Lang;
using Toybox.System as Sys;
using Toybox.WatchUi as Ui;
import Toybox.Application.Properties;

class YaTimeFieldApp extends Application.AppBase {
    function initialize() {
        AppBase.initialize();
        storeSetting("appVersion", "01.12.2021 #16"); //change it here (the only place)
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
}

function getApp() as YaTimeFieldApp {
    return Application.getApp() as YaTimeFieldApp;
}
