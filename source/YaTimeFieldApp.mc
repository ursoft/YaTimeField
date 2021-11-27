import Toybox.Application;
import Toybox.Lang;
using Toybox.System as Sys;
using Toybox.WatchUi as Ui;
import Toybox.Application.Properties;

class YaTimeFieldApp extends Application.AppBase {
    function storeSetting(name as String, value) as Void {
        try {
            if (Application has :Storage) {
                Properties.setValue(name, value);
            } else {
                AppBase.setProperty(name, value);
            }
        } catch(ex) {
            Sys.println("storeSetting exception: " + ex); 
        }
    }

    function readSetting(name as String, defValue) as Numeric or Boolead or String or Null {
        try {
            if (Application has :Storage) {
                var ret = Properties.getValue(name);
                return ret;
            } else {
                return AppBase.getProperty(name);
            }
        } catch(ex) {
            Sys.println("readSetting exception: " + ex); 
            storeSetting(name, defValue);
            return defValue;
        }
    }

    function initialize() {
        AppBase.initialize();
        storeSetting("appVersion", "27.11.2021");
        readAllSettings();
    }

    // onStart() is called on application start up
    function onStart(state as Dictionary?) as Void {
    }

    // onStop() is called when your application is exiting
    function onStop(state as Dictionary?) as Void {
    }

    var m_view as YaTimeFieldView = null;
    // Return the initial view of your application here
    function getInitialView() as Array<Views or InputDelegates>? {
        m_view = new YaTimeFieldView();
        return [ m_view ] as Array<Views or InputDelegates>;
    }

    var m_fieldCaptionVisible as Boolean = true;
    var m_flipSegments as Boolean = false;

    var m_fieldCaption as String = "";
    var m_fieldSources = [0, -1, -1, -1];

    function readAllSettings() {
        m_fieldCaptionVisible = true;
        m_flipSegments = false;
        m_fieldCaption = "";
        m_fieldSources[0] = 0;
        m_fieldSources[1] = -1;
        m_fieldSources[2] = -1;
        m_fieldSources[3] = -1;
        try {
            m_fieldCaptionVisible = readSetting("fieldCaptionVisible", m_fieldCaptionVisible);
            m_flipSegments = readSetting("flipSegments", m_flipSegments);
            m_fieldCaption = readSetting("fieldCaption", m_fieldCaption);
            m_fieldSources[0] = readSetting("fieldSource1", m_fieldSources[0]);
            m_fieldSources[1] = readSetting("fieldSource2", m_fieldSources[1]);
            m_fieldSources[2] = readSetting("fieldSource3", m_fieldSources[2]);
            m_fieldSources[3] = readSetting("fieldSource4", m_fieldSources[3]);
        } catch(ex) {
            Sys.println("readAllSettings exception: " + ex); 
        }
    }

    function onSettingsChanged() {
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
