import Toybox.Activity;
import Toybox.Lang;
import Toybox.Time;
using Toybox.WatchUi as Ui;

enum SourceKind { SK_timerTime, SK_clockTime, SK_elapsedTime, SK_timeLeft }
enum TimeGrowingDirection { TD_UP, TD_DOWN, TD_PAUSED, TD_STOPPED }
enum WhereIsUp { UP_IS_LEFT, UP_IS_RIGHT, UP_NORMAL }
enum ArrowDirection { AD_UP, AD_DOWN, AD_LEFT, AD_RIGHT }

//для теста
const ADD_SECONDS = 0;
const TEST_PAUSE = 0;

class TimeObj {
    var m_seconds as Long = 0, m_minutes as Long = 0, m_hours as Long = 0;
    var m_shouldShowHour as Boolean = false;
    function setTotalSeconds(totalSeconds as Long) {
        totalSeconds += ADD_SECONDS;
        m_seconds = totalSeconds % 60;
        var totalMinutes = totalSeconds / 60;
        m_minutes = totalMinutes % 60;
        m_hours = totalMinutes / 60;
    }
}

class DigitPainterBase {
    var m_dc as Graphics.Dc, m_direction as TimeGrowingDirection;
    var m_x, m_y, m_w, m_h; //rectangle in field coordinates
    var m_digitGap as Long, m_digitWidth as Long, m_curPosition as Long;
    var m_markSize as Long;

    var m_timeObj as TimeObj;
    var m_bPrintSeconds as Boolean = true;
    var m_bPrintHoursd as Boolean = true;
    var m_bPrintHours as Boolean = true;

    function initialize(timeObj, x, y, w, h) {
        m_timeObj = timeObj;
    }
    function CalcArrowDirection(rotation) {
        var ret = AD_UP;        
        switch(rotation) {
            case UP_IS_LEFT:
                ret = (m_direction == TD_DOWN) ? AD_RIGHT : AD_LEFT;
                break;
            case UP_IS_RIGHT:
                ret = (m_direction == TD_UP) ? AD_RIGHT : AD_LEFT;
                break;
            default: //normal
                if(m_direction == TD_DOWN) { ret = AD_DOWN; }
                break;
        }
        return ret;
    }
    function drawDirectionMarks(cx, cy, half_dist, isBlink, rotation) {
        if(isBlink) { m_dc.setPenWidth(3); }
        var dx = m_markSize/2; //3 & 4
        var dy = m_markSize/2; //4 & 8
        if(m_direction == TD_UP || m_direction == TD_DOWN) {
            var arrowDirection = CalcArrowDirection(rotation);
            switch(arrowDirection) {
                case AD_UP:
                    m_dc.drawLine(cx - dx, cy + dy + half_dist, cx, cy + half_dist);
                    m_dc.drawLine(cx + dx, cy + dy + half_dist, cx, cy + half_dist);
                    m_dc.drawLine(cx - dx, cy - half_dist, cx, cy - dy - half_dist);
                    m_dc.drawLine(cx + dx, cy - half_dist, cx, cy - dy - half_dist);
                    break;
                case AD_DOWN:
                    m_dc.drawLine(cx - dx, cy + half_dist, cx, cy + dy + half_dist);
                    m_dc.drawLine(cx + dx, cy + half_dist, cx, cy + dy + half_dist);
                    m_dc.drawLine(cx - dx, cy - dy - half_dist, cx, cy - half_dist);
                    m_dc.drawLine(cx + dx, cy - dy - half_dist, cx, cy - half_dist);
                    break;
                case AD_LEFT:
                    m_dc.drawLine(cx - half_dist - dx, cy, cx - half_dist, cy + dy);
                    m_dc.drawLine(cx - half_dist - dx, cy, cx - half_dist, cy - dy);
                    m_dc.drawLine(cx + half_dist, cy, cx + half_dist + dx, cy + dy);
                    m_dc.drawLine(cx + half_dist, cy, cx + half_dist + dx, cy - dy);
                    break;
                case AD_RIGHT:
                    m_dc.drawLine(cx - half_dist, cy, cx - half_dist - dx, cy + dy);
                    m_dc.drawLine(cx - half_dist, cy, cx - half_dist - dx, cy - dy);
                    m_dc.drawLine(cx + half_dist + dx, cy, cx + half_dist, cy + dy);
                    m_dc.drawLine(cx + half_dist + dx, cy, cx + half_dist, cy - dy);
                    break;
            }
        } else if(m_direction == TD_PAUSED) {
            switch(rotation) {
                case UP_IS_LEFT: case UP_IS_RIGHT:
                    m_dc.drawLine(cx - m_markSize, cy + dy, cx + m_markSize, cy + dy);
                    m_dc.drawLine(cx - m_markSize, cy - dy, cx + m_markSize, cy - dy);
                    break;
                default: //normal
                    m_dc.drawLine(cx - dx, cy + m_markSize, cx - dx, cy - m_markSize);
                    m_dc.drawLine(cx + dx, cy + m_markSize, cx + dx, cy - m_markSize);
                    break;
            }
        } else if(m_direction == TD_STOPPED) {
            m_dc.drawRectangle(cx - dy, cy - dy, 2 * (dy + 1), 2 * (dy + 1));
        }
        if(isBlink) { m_dc.setPenWidth(1); }
    }
    function drawAll(dc, direction, isBlink) {
        m_dc = dc;
        m_direction = direction;
        var digit as Number = m_timeObj.m_hours / 10;
        if(m_bPrintHoursd) { drawDigit(digit); }
        if(m_bPrintHours) {
            digit = m_timeObj.m_hours % 10;
            drawDigit(digit);
            drawDelimiter(isBlink);
        }
        digit = m_timeObj.m_minutes / 10;
        drawDigit(digit);
        digit = m_timeObj.m_minutes % 10;
        drawDigit(digit);
        if(m_bPrintSeconds) {
            drawDelimiter(isBlink);
            digit = m_timeObj.m_seconds / 10;
            drawDigit(digit);
            digit = m_timeObj.m_seconds % 10;
            drawDigit(digit);
        } else if(m_bPrintHours && isBlink) 
        {
            NotifySecondsHidden(); 
        }
    }
    function NotifySecondsHidden() {}
}

class DigitPainterVector extends DigitPainterBase {
    //4x6 matrix
    const SegmentDict = {
        0 => [[1,0, 3,0], [3,0, 4,1], [4,1, 4,5], [4,5, 3,6], [3,6, 1,6], [1,6, 0,5], [0,5, 0,1], [0,1, 1,0]],
        1 => [[1,0, 3,0], [2,0, 2,6], [2,6, 1,5]], 
        2 => [[0,5, 1,6], [1,6, 3,6], [3,6, 4,5], [4,5, 4,4], [4,4, 3,3], [3,3, 1,3], [1,3, 0,2], [0,2, 0,0], [0,0, 4,0]], 
        3 => [[0,5, 1,6], [1,6, 3,6], [3,6, 4,5], [4,5, 4,4], [4,4, 3,3], [3,3, 2,3], [3,3, 4,2], [4,2, 4,1], [4,1, 3,0], [3,0, 1,0], [1,0, 0,1]], 
        4 => [[3,0, 3,6], [3,6, 0,2], [0,2, 4,2]],
        5 => [[0,1, 1,0], [1,0, 3,0], [3,0, 4,1], [4,1, 4,3], [4,3, 3,4], [3,4, 0,4], [0,4, 0,6], [0,6, 4,6]],
        6 => [[3,6, 2,6], [2,6, 0,4], [0,4, 0,1], [0,1, 1,0], [1,0, 3,0], [3,0, 4,1], [4,1, 4,2], [4,2, 3,3], [3,3, 0,3]],
        7 => [[1,0, 4,6], [4,6, 0,6], [2,3, 3,3]],
        8 => [[1,3, 0,2], [0,2, 0,1], [0,1, 1,0], [1,0, 3,0], [3,0, 4,1], [4,1, 4,2], [4,2, 3,3], [3,3, 1,3], [1,3, 0,4], [0,4, 0,5], [0,5, 1,6], [1,6, 3,6], [3,6, 4,5], [4,5, 4,4], [4,4, 3,3]], 
        9 => [[1,0, 2,0], [2,0, 4,2], [4,2, 4,5], [4,5, 3,6], [3,6, 1,6], [1,6, 0,5], [0,5, 0,4], [0,4, 1,3], [1,3, 4,3]]
    };
    var m_flipSegments;
    var m_kx, m_ky, m_penWidth;
    function initialize(totalSeconds, x, y, w, h) {
        DigitPainterBase.initialize(totalSeconds, x, y, w, h);
        m_flipSegments = getApp().m_flipSegments;

        m_digitGap = w / 17;
        m_penWidth = m_digitGap / 2;
        m_markSize = m_digitGap - 2;
        m_x = x + m_digitGap; m_y = y + m_digitGap; 
        m_w = w - 2 * m_digitGap; m_h = h - 2 * m_digitGap;

        var digits = 6, delimiters = 2;
        if(m_timeObj.m_hours == 0 && !m_timeObj.m_shouldShowHour) {
            digits = 4;
            delimiters = 1;
            m_bPrintHoursd = false;
            m_bPrintHours = false;
        } else if(m_timeObj.m_hours < 10) {
            digits = 5;
            m_bPrintHoursd = false;
        }
        m_digitWidth = (m_h - m_digitGap * (digits / 2 + 2 * delimiters) - delimiters * m_markSize + digits / 2 /*anti-round*/) / digits;
        m_ky = m_digitWidth / 4;
        m_kx = m_w / 6;
        m_curPosition = m_y;
    }
    function drawDigit(digit as Number) {
        m_dc.setPenWidth(m_penWidth);
        if(digit < 0 || digit > 9) { digit = 0; }
        var lines = SegmentDict[digit.toNumber()];
        for(var i = 0; i < lines.size(); i++) {
            //each line is [x1, y1, x2, y2] in relative [0..4, 0..6] space
            var line = lines[i];
            var x1, y1, x2, y2;
            if(m_flipSegments) {
                x1 = m_w + m_x - m_kx * line[1]; x2 = m_w + m_x - m_kx * line[3];
                y1 = 2 * m_y + m_h - m_curPosition - m_ky * line[0]; y2 = 2 * m_y + m_h - m_curPosition - m_ky * line[2];
            } else {
                x1 = m_x + m_kx * line[1]; x2 = m_x + m_kx * line[3];
                y1 = m_curPosition + m_ky * line[0]; y2 = m_curPosition + m_ky * line[2];
            }
            m_dc.drawLine(x1, y1, x2, y2);
        }
        m_dc.setPenWidth(1);
        m_curPosition += (m_digitWidth + m_digitGap);
    }
    function drawDelimiter(isBlink) {
        var cx = m_x + m_w / 2, cy, rotation;
        if(m_flipSegments) {
            cy = 2 * m_y + m_h - m_curPosition - m_markSize / 2;
            rotation = UP_IS_LEFT;
        } else {
            cy = m_curPosition + m_markSize / 2;
            rotation = UP_IS_RIGHT;
        }
        drawDirectionMarks(cx, cy, m_w / 10, isBlink, rotation);
        m_curPosition += (m_markSize + m_digitGap);
    }
}
class DigitPainterFont extends DigitPainterBase {
    var m_font = Graphics.FONT_SYSTEM_NUMBER_THAI_HOT;
    function initialize(totalSeconds, x, y, w, h) {
        DigitPainterBase.initialize(totalSeconds, x, y, w, h);
        var digits = 6, delimiters = 2;
        if(w <= 140) {
            m_markSize = 6;

            if(m_timeObj.m_hours > 9) { //no place for the seconds
                m_bPrintSeconds = false;
                digits = 4;
                delimiters = 1;
            } else if(m_timeObj.m_hours > 0 || m_timeObj.m_shouldShowHour) {
                m_bPrintHoursd = false;
                digits = 5;
            } else {
                digits = 4;
                delimiters = 1;
                m_bPrintHours = false;
                m_bPrintHoursd = false;
            }
            if(digits == 4) {
                m_font = Graphics.FONT_SYSTEM_NUMBER_HOT;
                m_digitWidth = 29;
                m_digitGap = 2;
            } else {
                m_font = Graphics.FONT_SYSTEM_NUMBER_MILD;
                m_digitWidth = 20;
                m_digitGap = 1;
            }
        } else {
            m_digitWidth = 38;
            m_digitGap = 2;
            m_markSize = 8;
        }
        var need_x = m_digitWidth * digits + m_digitGap * (digits / 2 + 2 * delimiters) + delimiters * (m_markSize + 7);
        m_x = x + (w - need_x) / 2; //center!
        m_y = y + m_digitGap; 
        m_w = need_x; m_h = h - 2 * m_digitGap;

        m_curPosition = m_x;
    }
    function drawDigit(digit as Number) {
        if(digit < 0 || digit > 9) { digit = 0; }
        m_dc.drawText(m_curPosition + m_digitWidth / 2, m_y + m_h / 2 + m_digitWidth / 7, m_font, digit.format("%d"), Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        m_curPosition += (m_digitWidth + m_digitGap);
    }
    function NotifySecondsHidden() {
        m_dc.drawRectangle(m_curPosition - m_digitGap, m_y + m_h / 2 - m_digitWidth / 7, 3, 3);
    }
    function drawDelimiter(isBlink) {
        var cx = m_curPosition + m_markSize / 2 + 3, cy = m_y + m_h / 2;
        drawDirectionMarks(cx, cy, m_digitWidth / 6, isBlink, UP_NORMAL);
        m_curPosition += (m_markSize + m_digitGap + 6);
    }
}
class BaseSource {
    var m_defLabel as String = "";
    var m_timeObj = new TimeObj();

    function calcLabel(m_fieldCaption) as String {
        if(m_fieldCaption.length() == 0) {
            m_fieldCaption = m_defLabel;
        }
        return m_fieldCaption;
    }
    function onCompute(info as Activity.Info) {}
    function drawContent(dc, x, y, w, h) {
        dc.fillRoundedRectangle(x + 1, y + 1, w - 2, h - 2, 5);
    }
    function onUpdate(dc, x, y, w, h, label) {
        if(label.length()) {
            dc.drawText(x + 5, y, Graphics.FONT_SYSTEM_XTINY, label, Graphics.TEXT_JUSTIFY_LEFT);
            var labelHeight = dc.getFontHeight(Graphics.FONT_SYSTEM_XTINY);
            y += labelHeight;
            h -= labelHeight;
        }
        //dc.setClip(x, y, w, h); //ненадежно работает в симуляторе
        drawContent(dc, x, y, w, h);
        //dc.clearClip();
    }
    function drawTime(dc, x, y, w, h, direction) {
        var sp = (h > w) ? new DigitPainterVector(m_timeObj, x, y, w, h) : new DigitPainterFont(m_timeObj, x, y, w, h);
        var isBlink = (Time.now().value() & 1) != 0;
        sp.drawAll(dc, direction, isBlink);
    }
}
class TimerSource extends BaseSource {
    var m_notStartedLarge = Ui.loadResource(Rez.Strings.notStartedLarge); //"Timer\n\nis not\n\nstarted\n\nyet"
    var m_notStartedMedium = Ui.loadResource(Rez.Strings.notStartedMedium); //"Timer is not\n\nstarted yet"
    var m_notStarted = Ui.loadResource(Rez.Strings.notStarted); //"Timer is not\nstarted yet"
    var m_timerState as Long = 0;

    function onCompute(info as Activity.Info) {
        m_timeObj.setTotalSeconds(info.timerTime / 1000);
        m_timerState = info.timerState;
    }
    function initialize() {
        m_defLabel = Ui.loadResource(Rez.Strings.timerTimeSource);
        BaseSource.initialize();
    }
    function drawContent(dc, x, y, w, h) {
        if(m_timerState == Activity.TIMER_STATE_OFF) {
            var font = Graphics.FONT_SYSTEM_LARGE;
            var txt = m_notStarted;
            if(h > 400) {
                txt = m_notStartedLarge;
            } else if(h > 180) {
                txt = m_notStartedMedium;
            } else if(w > 140) {
                font = Graphics.FONT_SYSTEM_MEDIUM;
            } else {
                font = Graphics.FONT_SYSTEM_SMALL;
            }
            dc.drawText(x + w/2, y + h/2, font, txt, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            return;
        }
        var direction = TD_UP;
        switch(m_timerState) {
            //case Activity.TIMER_STATE_ON:
            case Activity.TIMER_STATE_PAUSED:  direction = (TEST_PAUSE ? TD_STOPPED : TD_PAUSED); break;
            case Activity.TIMER_STATE_STOPPED: direction = (TEST_PAUSE ? TD_PAUSED : TD_STOPPED); break;
        }
        drawTime(dc, x, y, w, h, direction);
    }
}
class ClockSource extends BaseSource {
    function initialize() {
        BaseSource.initialize();
    }
    function FormatUTC(offMinutes) as String {
        var ret as String;
        ret = " UTC" + (offMinutes > 0 ? "+" : "-");
        if(offMinutes < 0) { offMinutes = -offMinutes; }
        var minutes = offMinutes % 60;
        ret += (offMinutes / 60).format("%d");
        if(minutes != 0) { ret += ":" + minutes.format("%d"); }
        return ret;
    }
    function drawContent(dc, x, y, w, h) {
        var ct = System.getClockTime();
        m_timeObj.m_hours = ct.hour + ADD_SECONDS / 3600;
        m_timeObj.m_minutes = ct.min;
        m_timeObj.m_seconds = ct.sec;
        m_timeObj.m_shouldShowHour = true;
        m_defLabel = Ui.loadResource(Rez.Strings.clockTime) + FormatUTC(ct.timeZoneOffset/60);
        drawTime(dc, x, y, w, h, TD_UP);
    }
}
class ElapsedSource extends BaseSource {
    var m_startTime as Time.Moment = null;
    function onCompute(info as Activity.Info) {
        m_timeObj.setTotalSeconds(info.elapsedTime / 1000);
        m_startTime = info.startTime;
    }
    function initialize() {
        m_defLabel = Ui.loadResource(Rez.Strings.elapsedTime);
        BaseSource.initialize();
    }
    function drawContent(dc, x, y, w, h) {
        drawTime(dc, x, y, w, h, (m_startTime == null) ? TD_PAUSED : TD_UP);
    }
}
class TimeLeftSource extends BaseSource {
    var m_distRemains = null, m_elapsedDistance = null; //meters
    //var m_distRemains = 12000, m_elapsedDistance = 24000; //test
    var m_currentSpeed = null; //meters per second
    var m_oldRemainSeconds = null;
    var m_direction = TD_DOWN, m_progress = 0;
    function onCompute(info as Activity.Info) {
        m_defLabel = Ui.loadResource(Rez.Strings.timeLeft);
        m_progress = 0;

        m_distRemains = info.distanceToDestination; //or null
        m_currentSpeed = info.currentSpeed; //or null
        m_elapsedDistance = info.elapsedDistance; //or null
        //test:
        /*if(m_distRemains > 0) {
            m_elapsedDistance += 120;
            m_distRemains -= 120;
        }
        m_currentSpeed = 120;*/

        m_direction = TD_DOWN;
        if(m_distRemains == null || m_distRemains == 0) {
            m_direction = TD_STOPPED;
            m_oldRemainSeconds = null;
            m_timeObj.setTotalSeconds(0);
        } else if(m_currentSpeed == null || m_currentSpeed < 2.0) {
            m_direction = TD_PAUSED;
        } else {
            var newRemainSeconds = m_distRemains / m_currentSpeed;
            if(m_oldRemainSeconds != null && newRemainSeconds >= m_oldRemainSeconds) { m_direction = TD_UP; }
            m_oldRemainSeconds = newRemainSeconds;
            m_timeObj.setTotalSeconds(newRemainSeconds.toLong());
            if(m_elapsedDistance + m_distRemains > 1) {
                m_progress = m_elapsedDistance * 100 / (m_elapsedDistance + m_distRemains);
                m_defLabel += (" " + (100 - m_progress) + " %");
            }
        }
    }
    function initialize() {
        BaseSource.initialize();
    }
    function drawContent(dc, x, y, w, h) {
        drawTime(dc, x, y, w, h, m_direction);
        if(m_elapsedDistance != null && m_distRemains != null) {
            //we have a progress in %
            dc.drawRectangle(x + 1, y + h - 7, w - 2, 7);
            dc.setPenWidth(3);
            dc.fillRectangle(x + 1, y + h - 7, m_progress * (w - 2) / 100, 6);
            dc.setPenWidth(1);
        }
    }
}
class YaTimeFieldView extends Ui.DataField {
    var m_app = Application.getApp();
    var m_fieldSources = new [m_app.m_fieldSources.size()];
    var m_fieldSourcesCnt = 0;
    function calcLabel(i) as String {
        var ret as String = "";
        if(m_app.m_fieldCaptionVisible) {
            var src = m_fieldSources[i];
            if(src != null) {
                ret = src.calcLabel(m_app.m_fieldCaption);
                if(ret.length() == 0) {
                    ret = "YaTimeField" + i.toString();
                }
            }
        }
        return ret;
    }
    function initialize() {
        Ui.DataField.initialize();
        rebuildSources();
    }
    function onUpdate(dc) {
        var foreColor = Graphics.COLOR_WHITE;
        var backColor = getBackgroundColor();
        if(backColor != Graphics.COLOR_BLACK) {
            foreColor = Graphics.COLOR_BLACK;
        }
        dc.setColor(foreColor, backColor);
        dc.clear();

        var w = dc.getWidth();
        var h = dc.getHeight();

        //как можно больше полей из m_fieldSources упихать в данное нам место
        //не отказываясь от большого шрифта
        if(w < 150 || m_fieldSourcesCnt == 1) {
            //самый простой случай - 140х93 и/или только одно поле
            m_fieldSources[0].onUpdate(dc, 0, 0, w, h, calcLabel(0));
        } else if(h  < 150) {
            //тут вместим оба
            m_fieldSources[0].onUpdate(dc, 0, 0, w/2 - 1, h, calcLabel(0));
            m_fieldSources[1].onUpdate(dc, w/2 + 1, 0, w/2 - 1, h, calcLabel(1));
            dc.drawLine(w/2, 0, w/2, h); //vert
        } else if(h  < 240) {
            //все влезут
            if(m_fieldSourcesCnt == 4) { //2x2
                m_fieldSources[0].onUpdate(dc, 0, 0, w/2 - 1, h/2 - 1, calcLabel(0));
                m_fieldSources[1].onUpdate(dc, w/2 + 1, 0, w/2 - 1, h/2 - 1, calcLabel(1));
                m_fieldSources[2].onUpdate(dc, 0, h/2 + 1, w/2 - 1, h/2 - 1, calcLabel(2));
                m_fieldSources[3].onUpdate(dc, w/2 + 1, h/2 + 1, w/2 - 1, h/2 - 1, calcLabel(3));
                dc.drawLine(w/2, 0, w/2, h); //vert
            } else if(m_fieldSourcesCnt == 3) { // 1+2
                m_fieldSources[0].onUpdate(dc, 0, 0, w, h/2 - 1, calcLabel(0));
                m_fieldSources[1].onUpdate(dc, 0, h/2 + 1, w/2 - 1, h/2 - 1, calcLabel(1));
                m_fieldSources[2].onUpdate(dc, w/2 + 1, h/2 + 1, w/2 - 1, h/2 - 1, calcLabel(2));
                dc.drawLine(w/2, h/2, w/2, h); //vert
            } else { // 1+1
                m_fieldSources[0].onUpdate(dc, 0, 0, w, h/2 - 1, calcLabel(0));
                m_fieldSources[1].onUpdate(dc, 0, h/2 + 1, w, h/2 - 1, calcLabel(1));
            }
            dc.drawLine(0, h/2, w, h/2); //horz
        } else { // несколько линий
            for(var i = 0; i < m_fieldSourcesCnt; i++) {
                var minY = i * h/m_fieldSourcesCnt;
                var maxY = (i + 1) * h/m_fieldSourcesCnt;
                m_fieldSources[i].onUpdate(dc, 0, minY + 1, w, h/m_fieldSourcesCnt - 1, calcLabel(i));
                if(i < m_fieldSourcesCnt - 1) { dc.drawLine(0, maxY, w, maxY); } //horz
            }
        }
    }
    function rebuildSources() {
        var j = 0;
        for(var i = 0; i < m_app.m_fieldSources.size(); i++) {
            var newSrc = sourceFactory(m_app.m_fieldSources[i]);
            if(newSrc != null) {
               m_fieldSources[j] = newSrc;
               j++;
            }
        }
        if(j == 0) {
            m_fieldSources[j] = sourceFactory(0);
            j++;
        }
        m_fieldSourcesCnt = j;
        for(; j < m_app.m_fieldSources.size(); j++ ) {
            m_fieldSources[j] = null;
        }
    }
    function sourceFactory(i) {
        switch(i) {
            case SK_timerTime:   return new TimerSource();
            case SK_clockTime:   return new ClockSource();
            case SK_elapsedTime: return new ElapsedSource();
            case SK_timeLeft:    return new TimeLeftSource();
            default:             return null;
        }
    }
    function compute(info as Activity.Info) {
        for(var i = 0; i < m_fieldSources.size(); i++) {
            var src = m_fieldSources[i];
            if(src == null) { break; }
            src.onCompute(info);
        }
    }
}
