import Toybox.Activity;
import Toybox.Lang;
import Toybox.Time;
using Toybox.WatchUi as Ui;

//для тестирования (в релизе поставить всё по 0)
const TEST_ADD_SECONDS = 0;  // увеличить отображаемое время, чтобы отработал алгоритм показа часов, например
const TEST_PAUSE = false;    // показывать символ паузы вместо символа "стоп" поля timerTime
const TEST_REMAINS = false;  // тест прогноза времени финиша
const TEST_RECTS = false;    // тест вычислений координат

enum SourceKind { SK_timerTime, SK_clockTime, SK_elapsedTime, SK_timeLeft, SK_lapTime, SK_avgLapTime, SK_timeBehind, SK_workoutDuration,
    SK_timeToGo, SK_stepTime, SK_timeToRecovery }
enum TimeGrowingDirection { TD_UP, TD_DOWN, TD_PAUSED, TD_STOPPED }
enum ArrowDirection { AD_UP, AD_DOWN, AD_LEFT, AD_RIGHT } // относительно текста времени
enum WhereIsUp { 
    UP_IS_LEFT,   // стрелка вверх на самом деле указывает на левый бок книжно поставленного устройства (т.е. ландшафт+перевернуть)
    UP_IS_RIGHT,  // то же самое, не переворачивать
    UP_NORMAL     // книжное расположение текста
}
enum Dims1030 { FULL_WIDTH = 282, HALF_WIDTH = 140, FULL_HEIGHT = 470, HALF_HEIGHT = 234, 
    B3_HEIGHT = 186 /*or 187*/,
    THIRD_HEIGHT = 154 /*or 155*/,
    FOURTH_HEIGHT = 115 /*or 116*/,
    /*FIFTH_HEIGHT = 92 or 93*/  }

class TimeObj {
    var m_seconds as Long = 0, m_minutes as Long = 0, m_hours as Long = 0;
    var m_shouldShowHour as Boolean = false; //полезно, если 0 часов все-таки лучше нарисовать, чем откинуть (время суток, например)
    function setTotalSeconds(totalSeconds as Long) {
        totalSeconds += TEST_ADD_SECONDS;
        m_seconds = totalSeconds % 60;
        var totalMinutes = totalSeconds / 60;
        m_minutes = totalMinutes % 60;
        m_hours = totalMinutes / 60;
    }
}

class DrawContext {
    var m_dc, m_foreColor, m_backColor, m_inversed;
    function initialize(dc, foreColor, backColor, inversed) {
        m_dc = dc; m_foreColor = foreColor; m_backColor = backColor; m_inversed = inversed;
    }
}

class DigitPainterBase {
    var m_drawContext as DrawContext, m_direction as TimeGrowingDirection;
    var m_x, m_y, m_w, m_h; //rectangle in field coordinates
    var m_digitGap as Long, m_digitWidth as Long, m_curPosition as Long;
    var m_markSize as Long;

    var m_timeObj as TimeObj, m_digits = 6, m_delimiters = 2;
    var m_bPrintSeconds as Boolean = true;
    var m_bPrintHoursd as Boolean = true;
    var m_bPrintHours as Boolean = true;

    function initialize(timeObj, drawContext, x, y, w, h) {
        m_timeObj = timeObj;
        m_drawContext = drawContext;
        m_x = x; m_y = y; m_w = w; m_h = h;
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
                if (m_direction == TD_DOWN) { ret = AD_DOWN; }
                break;
        }
        return ret;
    }
    function drawDirectionMarks(cx, cy, half_dist, isBlink, rotation) {
        if (isBlink) { m_drawContext.m_dc.setPenWidth(3); }
        var wingSize = m_markSize / 2;
        if (m_direction == TD_UP || m_direction == TD_DOWN) {
            var arrowDirection = CalcArrowDirection(rotation);
            switch(arrowDirection) {
                case AD_UP:
                    m_drawContext.m_dc.drawLine(cx - wingSize, cy + wingSize + half_dist, cx, cy + half_dist);
                    m_drawContext.m_dc.drawLine(cx + wingSize, cy + wingSize + half_dist, cx, cy + half_dist);
                    m_drawContext.m_dc.drawLine(cx - wingSize, cy - half_dist, cx, cy - wingSize - half_dist);
                    m_drawContext.m_dc.drawLine(cx + wingSize, cy - half_dist, cx, cy - wingSize - half_dist);
                    break;
                case AD_DOWN:
                    m_drawContext.m_dc.drawLine(cx - wingSize, cy + half_dist, cx, cy + wingSize + half_dist);
                    m_drawContext.m_dc.drawLine(cx + wingSize, cy + half_dist, cx, cy + wingSize + half_dist);
                    m_drawContext.m_dc.drawLine(cx - wingSize, cy - wingSize - half_dist, cx, cy - half_dist);
                    m_drawContext.m_dc.drawLine(cx + wingSize, cy - wingSize - half_dist, cx, cy - half_dist);
                    break;
                case AD_LEFT:
                    m_drawContext.m_dc.drawLine(cx - half_dist - wingSize, cy, cx - half_dist, cy + wingSize);
                    m_drawContext.m_dc.drawLine(cx - half_dist - wingSize, cy, cx - half_dist, cy - wingSize);
                    m_drawContext.m_dc.drawLine(cx + half_dist, cy, cx + half_dist + wingSize, cy + wingSize);
                    m_drawContext.m_dc.drawLine(cx + half_dist, cy, cx + half_dist + wingSize, cy - wingSize);
                    break;
                case AD_RIGHT:
                    m_drawContext.m_dc.drawLine(cx - half_dist, cy, cx - half_dist - wingSize, cy + wingSize);
                    m_drawContext.m_dc.drawLine(cx - half_dist, cy, cx - half_dist - wingSize, cy - wingSize);
                    m_drawContext.m_dc.drawLine(cx + half_dist + wingSize, cy, cx + half_dist, cy + wingSize);
                    m_drawContext.m_dc.drawLine(cx + half_dist + wingSize, cy, cx + half_dist, cy - wingSize);
                    break;
            }
        } else if (m_direction == TD_PAUSED) {
            switch(rotation) {
                case UP_IS_LEFT: case UP_IS_RIGHT:
                    m_drawContext.m_dc.drawLine(cx - m_markSize, cy + wingSize, cx + m_markSize, cy + wingSize);
                    m_drawContext.m_dc.drawLine(cx - m_markSize, cy - wingSize, cx + m_markSize, cy - wingSize);
                    break;
                default: //normal
                    m_drawContext.m_dc.drawLine(cx - wingSize, cy + m_markSize, cx - wingSize, cy - m_markSize);
                    m_drawContext.m_dc.drawLine(cx + wingSize, cy + m_markSize, cx + wingSize, cy - m_markSize);
                    break;
            }
        } else if (m_direction == TD_STOPPED) {
            m_drawContext.m_dc.drawRectangle(cx - wingSize, cy - wingSize, 2 * (wingSize + 1), 2 * (wingSize + 1));
        }
        if (isBlink) { m_drawContext.m_dc.setPenWidth(1); }
    }
    function drawAllDigits(direction, isBlink) {
        if(TEST_RECTS) {
            m_drawContext.m_dc.drawRectangle(m_x, m_y, m_w, m_h);
            m_drawContext.m_dc.drawLine(m_x, m_y, m_x + m_w, m_y + m_h);
        }

        m_direction = direction;
        var digit as Number = m_timeObj.m_hours / 10;
        if (m_bPrintHoursd) { drawDigit(digit); }
        if (m_bPrintHours) {
            digit = m_timeObj.m_hours % 10;
            drawDigit(digit);
            drawDelimiter(isBlink);
        }
        digit = m_timeObj.m_minutes / 10;
        drawDigit(digit);
        digit = m_timeObj.m_minutes % 10;
        drawDigit(digit);
        if (m_bPrintSeconds) {
            drawDelimiter(isBlink);
            digit = m_timeObj.m_seconds / 10;
            drawDigit(digit);
            digit = m_timeObj.m_seconds % 10;
            drawDigit(digit);
        } else if (m_bPrintHours && isBlink) 
        {
            NotifySecondsHidden(); 
        }
    }
    function drawProgress(percent) {
        if(m_w > m_h) {
            m_drawContext.m_dc.fillRectangle(m_x + 1, m_y + 1, percent * (m_w - 2) / 100, m_h - 2);
        } else {
            m_drawContext.m_dc.fillRectangle(m_x + 1, m_y + 1, m_w - 2, percent * (m_h - 2) / 100);
        }
    }
    function NotifySecondsHidden() {}
}
class DigitPainterVectorBase extends DigitPainterBase {
    //4x6 matrix
    const SegmentDict = {
        0 => [[1,0, 3,0], [3,0, 4,1], [4,1, 4,5], [4,5, 3,6], [3,6, 1,6], [1,6, 0,5], [0,5, 0,1], [0,1, 1,0]],
        1 => [[1,0, 3,0], [2,0, 2,6], [2,6, 1,5]], 
        2 => [[0,5, 1,6], [1,6, 3,6], [3,6, 4,5], [4,5, 4,4], [4,4, 3,3], [3,3, 1,3], [1,3, 0,2], [0,2, 0,0], [0,0, 4,0]], 
        3 => [[0,5, 1,6], [1,6, 3,6], [3,6, 4,5], [4,5, 4,4], [4,4, 3,3], [3,3, 2,3], [3,3, 4,2], [4,2, 4,1], [4,1, 3,0], [3,0, 1,0], [1,0, 0,1]], 
        4 => [[3,0, 3,6], [1,6, 0,2], [0,2, 4,2]],
        5 => [[0,1, 1,0], [1,0, 3,0], [3,0, 4,1], [4,1, 4,3], [4,3, 3,4], [3,4, 0,4], [0,4, 0,6], [0,6, 4,6]],
        6 => [[3,6, 2,6], [2,6, 0,4], [0,4, 0,1], [0,1, 1,0], [1,0, 3,0], [3,0, 4,1], [4,1, 4,2], [4,2, 3,3], [3,3, 0,3]],
        7 => [[1,0, 4,6], [4,6, 0,6], [2,3, 3,3]],
        8 => [[1,3, 0,2], [0,2, 0,1], [0,1, 1,0], [1,0, 3,0], [3,0, 4,1], [4,1, 4,2], [4,2, 3,3], [3,3, 1,3], [1,3, 0,4], [0,4, 0,5], [0,5, 1,6], [1,6, 3,6], [3,6, 4,5], [4,5, 4,4], [4,4, 3,3]], 
        9 => [[1,0, 2,0], [2,0, 4,2], [4,2, 4,5], [4,5, 3,6], [3,6, 1,6], [1,6, 0,5], [0,5, 0,4], [0,4, 1,3], [1,3, 4,3]]
    };
    var m_kx, m_ky, m_penWidth;
    function initialize(timeObj, drawContext, x, y, w, h) {
        DigitPainterBase.initialize(timeObj, drawContext, x, y, w, h);

        if (m_timeObj.m_hours == 0 && !m_timeObj.m_shouldShowHour) {
            m_digits = 4;
            m_delimiters = 1;
            m_bPrintHoursd = false;
            m_bPrintHours = false;
        } else if (m_timeObj.m_hours < 10) {
            m_digits = 5;
            m_bPrintHoursd = false;
        }
    }
    function CalcDigitWidth(space) {
        m_digitWidth = (space - m_digitGap * (2 + m_digits / 2 + 2 * m_delimiters) - m_delimiters * m_markSize + m_digits / 2 /*anti-round*/) / m_digits;
    }
}
class DigitPainterVectorBook extends DigitPainterVectorBase {
    function initialize(timeObj, drawContext, x, y, w, h) {
        if (w <= HALF_WIDTH) {
            m_markSize = 6;
            m_penWidth = 5;
        } else {
            m_markSize = 8;
            m_penWidth = 6;
        }
        m_digitGap = m_markSize + 2;
        DigitPainterVectorBase.initialize(timeObj, drawContext, x, y, w, h);
        CalcDigitWidth(m_w);

        m_kx = m_digitWidth / 4;
        m_ky = (m_h - 2 * m_digitGap) / 6;
        m_curPosition = m_digitGap + m_x;

        if(m_digitWidth / m_penWidth < 2) {
            m_penWidth = m_digitWidth / 2;
        }
    }
    function drawDigit(digit as Number) {
        m_drawContext.m_dc.setPenWidth(m_penWidth);
        if (digit < 0 || digit > 9) { digit = 0; }
        var lines = SegmentDict[digit.toNumber()];
        for(var i = 0; i < lines.size(); i++) {
            //each line is [x1, y1, x2, y2] in relative [0..4, 0..6] space
            var line = lines[i];
            var x1 = m_curPosition + m_kx * line[0] + 1; var x2 = m_curPosition + m_kx * line[2] + 1;
            var y1 = m_y + m_h - m_digitGap - m_ky * line[1]; var y2 = m_y + m_h - m_ky * line[3] - m_digitGap;
            m_drawContext.m_dc.drawLine(x1, y1, x2, y2);
        }
        m_drawContext.m_dc.setPenWidth(1);
        m_curPosition += (m_digitWidth + m_digitGap);
        if(TEST_RECTS) {
            m_drawContext.m_dc.drawRectangle(m_curPosition, m_y, m_curPosition, m_y + m_w);
        }
    }
    function drawDelimiter(isBlink) {
        var cy = m_y + m_h / 2, cx = m_curPosition + m_markSize / 2;
        drawDirectionMarks(cx, cy, m_h / 10, isBlink, UP_NORMAL);
        m_curPosition += (m_markSize + m_digitGap);
    }
}
class DigitPainterVectorLandscape extends DigitPainterVectorBase {
    var m_flipLandscape;
    function drawProgress(percent) {
        if(m_flipLandscape) {
            var nonFilledSize = (100 - percent) * (m_h - 2) / 100;
            m_drawContext.m_dc.fillRectangle(m_x + 1, nonFilledSize + m_y + 1, m_w - 2, m_h - 2 - nonFilledSize);
        } else {
            DigitPainterVectorBase.drawProgress(percent);
        }
    }
    function initialize(timeObj, drawContext, x, y, w, h) {
        m_flipLandscape = getApp().m_flipLandscape;
        m_digitGap = w / 17;
        m_penWidth = m_digitGap / 2;
        m_markSize = m_digitGap - 2;
        DigitPainterVectorBase.initialize(timeObj, drawContext, x, y, w, h);
        CalcDigitWidth(m_h);

        m_ky = m_digitWidth / 4;
        m_kx = (m_w - 2 * m_digitGap) / 6;
        m_curPosition = m_digitGap + m_y;
    }
    function drawDigit(digit as Number) {
        m_drawContext.m_dc.setPenWidth(m_penWidth);
        if (digit < 0 || digit > 9) { digit = 0; }
        var lines = SegmentDict[digit.toNumber()];
        for(var i = 0; i < lines.size(); i++) {
            //each line is [x1, y1, x2, y2] in relative [0..4, 0..6] space
            var line = lines[i];
            var x1, y1, x2, y2;
            if (m_flipLandscape) {
                x1 = m_w + m_x - m_kx * line[1] - m_digitGap - m_penWidth / 3; x2 = m_w + m_x - m_kx * line[3] - m_digitGap - m_penWidth / 3;
                y1 = 2 * m_y + m_h - m_curPosition - m_ky * line[0] - 1; y2 = 2 * m_y + m_h - m_curPosition - m_ky * line[2] - 1;
            } else {
                x1 = m_digitGap + m_x + m_kx * line[1] + m_penWidth / 3; x2 = m_digitGap + m_x + m_kx * line[3] + m_penWidth / 3;
                y1 = m_curPosition + m_ky * line[0]; y2 = m_curPosition + m_ky * line[2];
            }
            m_drawContext.m_dc.drawLine(x1, y1, x2, y2);
        }
        m_drawContext.m_dc.setPenWidth(1);
        m_curPosition += (m_digitWidth + m_digitGap);
        if(TEST_RECTS) {
            m_drawContext.m_dc.drawRectangle(m_x, m_curPosition, m_x + m_w, m_curPosition);
        }
    }
    function drawDelimiter(isBlink) {
        var cx = m_x + m_w / 2, cy, rotation;
        if (m_flipLandscape) {
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
    function initialize(timeObj, drawContext, x, y, w, h) {
        DigitPainterBase.initialize(timeObj, drawContext, x, y, w, h);
        if (w <= HALF_WIDTH) {
            m_markSize = 6;

            if (m_timeObj.m_hours > 9) { //no place for the seconds
                m_bPrintSeconds = false;
                m_digits = 4;
                m_delimiters = 1;
            } else if (m_timeObj.m_hours > 0 || m_timeObj.m_shouldShowHour) {
                m_bPrintHoursd = false;
                m_digits = 5;
            } else {
                m_digits = 4;
                m_delimiters = 1;
                m_bPrintHours = false;
                m_bPrintHoursd = false;
            }
            if (m_digits == 4) {
                m_font = Graphics.FONT_SYSTEM_NUMBER_HOT;
                m_digitWidth = 29;
                m_digitGap = 2;
            } else {
                m_font = Graphics.FONT_SYSTEM_NUMBER_MILD;
                m_digitWidth = 20;
                m_digitGap = 1;
            }
        } else {
            if(h < B3_HEIGHT) {
                m_font = Graphics.FONT_SYSTEM_NUMBER_HOT;
                m_digitWidth = 29;
                m_digitGap = 2;
                m_markSize = 6;
            } else {
                m_digitWidth = 38;
                m_digitGap = 2;
                m_markSize = 8;
            }
        }
        var need_x = m_digitWidth * m_digits + m_digitGap * (2 + m_digits / 2 + 2 * m_delimiters) + m_delimiters * (m_markSize + 7);
        m_curPosition = x + (w - need_x) / 2 + m_digitGap; //center!
    }
    function drawDigit(digit as Number) {
        if (digit < 0 || digit > 9) { digit = 0; }
        m_drawContext.m_dc.drawText(m_curPosition + m_digitWidth / 2, m_y + m_h / 2 + m_digitWidth / 7, m_font, digit.format("%d"), Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        m_curPosition += (m_digitWidth + m_digitGap);
        if(TEST_RECTS) {
            m_drawContext.m_dc.drawRectangle(m_curPosition, m_y, m_curPosition, m_y + m_w);
        }
    }
    function NotifySecondsHidden() {
        m_drawContext.m_dc.drawRectangle(m_curPosition - m_digitGap, m_y + m_h / 2 - m_digitWidth / 7, 3, 3);
    }
    function drawDelimiter(isBlink) {
        var cx = m_curPosition + m_markSize / 2 + 3, cy = m_y + m_h / 2;
        drawDirectionMarks(cx, cy, m_digitWidth / 6, isBlink, UP_NORMAL);
        m_curPosition += (m_markSize + m_digitGap + 6);
    }
}

class BaseSource {
    var m_defLabelId as String, m_defLabelSuffix = "";
    var m_timeObj = new TimeObj();

    function initialize(labelId) { m_defLabelId = labelId; }
    function calcLabel(fieldCaption) as String {
        if (fieldCaption.length() == 0) {
            fieldCaption = Ui.loadResource(m_defLabelId) + m_defLabelSuffix;
        }
        return fieldCaption;
    }
    function onCompute(info as Activity.Info) {}
    function preDrawTime(sp, direction, isBlink) {}
    function postDrawTime(sp, direction, isBlink) {}
    function drawContent(drawContext, x, y, w, h) {
        drawContext.m_dc.fillRoundedRectangle(x + 1, y + 1, w - 2, h - 2, 5);
    }
    function onUpdate(drawContext, x, y, w, h, label) {
        if (label.length()) {
            drawContext.m_dc.drawText(x + 5, y, Graphics.FONT_SYSTEM_XTINY, label, Graphics.TEXT_JUSTIFY_LEFT);
            var labelHeight = drawContext.m_dc.getFontHeight(Graphics.FONT_SYSTEM_XTINY);
            y += labelHeight;
            h -= labelHeight;
        }
        //drawContext.m_dc.setClip(x, y, w, h); //ненадежно работает в симуляторе
        drawContent(drawContext, x, y, w, h);
        //drawContext.m_dc.clearClip();
    }
    function drawTime(drawContext, x, y, w, h, direction) {
        var sp = (h > w) ? 
            new DigitPainterVectorLandscape(m_timeObj, drawContext, x, y, w, h) : 
                getApp().m_forceVectorFont ? new DigitPainterVectorBook(m_timeObj, drawContext, x, y, w, h) :
                                             new DigitPainterFont(m_timeObj, drawContext, x, y, w, h);
        var isBlink = (Time.now().value() & 1) != 0;
        preDrawTime(sp, direction, isBlink);
        sp.drawAllDigits(direction, isBlink);
        postDrawTime(sp, direction, isBlink);
    }
}
class TimerSource extends BaseSource {
    var m_timerState as Long = 0;
    function onCompute(info as Activity.Info) {
        m_timeObj.setTotalSeconds(info.timerTime / 1000);
        m_timerState = info.timerState;
    }
    function initialize() { BaseSource.initialize(Rez.Strings.timerTimeSource); }
    function drawContent(drawContext, x, y, w, h) {
        if (m_timerState == Activity.TIMER_STATE_OFF) {
            var font = Graphics.FONT_SYSTEM_LARGE;
            var txt = null;
            if (h > HALF_HEIGHT) {
                txt = Ui.loadResource(Rez.Strings.notStartedLarge); //"Timer\n\nis not\n\nstarted\n\nyet"
            } else if (h == HALF_HEIGHT) {
                txt = Ui.loadResource(Rez.Strings.notStartedMedium); //"Timer is not\n\nstarted yet"
            } else if (w > HALF_WIDTH) {
                if (h < FOURTH_HEIGHT) { font = Graphics.FONT_SYSTEM_MEDIUM; }
            } else {
                font = Graphics.FONT_SYSTEM_SMALL;
            }
            if (txt == null) { txt = Ui.loadResource(Rez.Strings.notStarted); } //"Timer is not\nstarted yet"
            drawContext.m_dc.drawText(x + w/2, y + h/2,
                font, txt, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            return;
        }
        var direction = TD_UP;
        switch(m_timerState) {
            //case Activity.TIMER_STATE_ON:
            case Activity.TIMER_STATE_PAUSED:  direction = (TEST_PAUSE ? TD_STOPPED : TD_PAUSED); break;
            case Activity.TIMER_STATE_STOPPED: direction = (TEST_PAUSE ? TD_PAUSED : TD_STOPPED); break;
        }
        drawTime(drawContext, x, y, w, h, direction);
    }
}
class ClockSource extends BaseSource {
    function initialize() { BaseSource.initialize(Rez.Strings.clockTime); }
    function FormatUTC(offMinutes) as String {
        var ret as String;
        ret = " UTC" + (offMinutes > 0 ? "+" : "-");
        if (offMinutes < 0) { offMinutes = -offMinutes; }
        var minutes = offMinutes % 60;
        ret += (offMinutes / 60).format("%d");
        if (minutes != 0) { ret += ":" + minutes.format("%d"); }
        return ret;
    }
    function drawContent(drawContext, x, y, w, h) {
        var ct = System.getClockTime();
        m_timeObj.m_hours = ct.hour + TEST_ADD_SECONDS / 3600;
        m_timeObj.m_minutes = ct.min;
        m_timeObj.m_seconds = ct.sec;
        m_timeObj.m_shouldShowHour = true;
        m_defLabelSuffix = FormatUTC(ct.timeZoneOffset / 60);
        drawTime(drawContext, x, y, w, h, TD_UP);
    }
}
class ElapsedSource extends BaseSource {
    var m_startTime as Time.Moment = null;
    function onCompute(info as Activity.Info) {
        m_timeObj.setTotalSeconds(info.elapsedTime / 1000);
        m_startTime = info.startTime;
    }
    function initialize() { BaseSource.initialize(Rez.Strings.elapsedTime); }
    function drawContent(drawContext, x, y, w, h) {
        drawTime(drawContext, x, y, w, h, (m_startTime == null) ? TD_PAUSED : TD_UP);
    }
}
class TimeLeftSource extends BaseSource {
    var m_distRemains = null, m_elapsedDistance = null; //meters
    var m_currentSpeed = null; //meters per second
    var m_oldRemainSeconds = null;
    var m_direction = TD_DOWN, m_progress = 0;
    function initialize() {
        BaseSource.initialize(Rez.Strings.timeLeft);
        if (TEST_REMAINS) { m_distRemains = 12000; m_elapsedDistance = 24000; }
    }
    function onCompute(info as Activity.Info) {
        if (TEST_REMAINS) {
            m_currentSpeed = 1200;
            if (m_distRemains > 0) {
                m_elapsedDistance += m_currentSpeed;
                m_distRemains -= m_currentSpeed;
            }
        } else {
            m_distRemains = info.distanceToDestination; //or null
            m_currentSpeed = info.currentSpeed; //or null
            m_elapsedDistance = info.elapsedDistance; //or null
        }

        m_progress = 0;
        m_direction = TD_DOWN;
        if (m_distRemains == null || m_distRemains == 0) {
            m_direction = TD_STOPPED;
            m_oldRemainSeconds = null;
            m_timeObj.setTotalSeconds(0);
            m_defLabelSuffix = "";
        } else if (m_currentSpeed == null || m_currentSpeed < 2.0) {
            m_direction = TD_PAUSED;
        } else {
            var newRemainSeconds = m_distRemains / m_currentSpeed;
            if (m_oldRemainSeconds != null && newRemainSeconds >= m_oldRemainSeconds) { m_direction = TD_UP; }
            m_oldRemainSeconds = newRemainSeconds;
            m_timeObj.setTotalSeconds(newRemainSeconds.toLong());
            if (m_elapsedDistance + m_distRemains > 1) {
                m_progress = m_elapsedDistance * 100 / (m_elapsedDistance + m_distRemains);
                m_defLabelSuffix = (" " + (100 - m_progress) + " %");
            }
        }
    }
    function drawContent(drawContext, x, y, w, h) {
        drawTime(drawContext, x, y, w, h, m_direction);
    }
    function preDrawTime(sp, direction, isBlink) {
        if (m_elapsedDistance != null && m_distRemains != null) {
            //we have a progress in %
            sp.m_drawContext.m_dc.setColor( 
                (m_direction != TD_UP)   ? (sp.m_drawContext.m_inversed ? Graphics.COLOR_DK_GREEN : Graphics.COLOR_GREEN)
                                         : (sp.m_drawContext.m_inversed ? Graphics.COLOR_DK_RED : Graphics.COLOR_RED),
                Graphics.COLOR_TRANSPARENT);
            sp.drawProgress(m_progress);
            sp.m_drawContext.m_dc.setColor(sp.m_drawContext.m_foreColor, Graphics.COLOR_TRANSPARENT);
        }
        BaseSource.preDrawTime(sp, direction, isBlink);
    }
}
//todo
// Время круга (Lap Time)
class LapTimeSource extends BaseSource {
    function initialize() { BaseSource.initialize(Rez.Strings.lapTime); }
}
// Среднее время круга (Avg Lap Time)
class AvgLapTimeSource extends BaseSource {
    function initialize() { BaseSource.initialize(Rez.Strings.avgLapTime); }
}
// Время отставания (кр/зел?) от вирт. партнера (Time Behind)
class TimeBehindSource extends BaseSource {
    function initialize() { BaseSource.initialize(Rez.Strings.timeBehind); }
}
// Длительность тренировки - идет вниз, равно следующему, останавливается паузой тренировки, пустеет с отменой,
//  если тренировка поэтапная, подсказку пишет (разминка, например) - Duration
class WorkoutDurationSource extends BaseSource {
    function initialize() { BaseSource.initialize(Rez.Strings.workoutDuration); }
}
// Ост. время тренировки - идет вниз, останавливается паузой тренировки, минусуется (__:__:__) с отменой Time to Go
class TimeToGoSource extends BaseSource {
    function initialize() { BaseSource.initialize(Rez.Strings.timeToGo); }
}
// Время этапа тренировки - идет вверх, останавливается паузой тренировки, минусуется (__:__:__) с отменой Step Time
class StepTimeSource extends BaseSource {
    /*var m_startTime as Time.Moment = null;
    function onCompute(info as Activity.Info) {
        m_timeObj.setTotalSeconds(info.elapsedTime / 1000);
        m_startTime = info.startTime;
    }*/
/*Activity.getCurrentWorkoutStep() as Activity.WorkoutStepInfo 
.step = Activity.WorkoutStep or Activity.WorkoutIntervalStep
 WorkoutStep: .durationValue при .step.durationType=WORKOUT_STEP_DURATION_TIME 
 WorkoutIntervalStep .ActiveStep/.RestStep*/
    function initialize() { BaseSource.initialize(Rez.Strings.stepTime); }
    /*function drawContent(dc, x, y, w, h) {
        drawTime(dc, x, y, w, h, (m_startTime == null) ? TD_PAUSED : TD_UP);
    }*/
}
// Время восстановления Time To Recovery
class TimeToRecoverySource extends BaseSource {
    function initialize() { BaseSource.initialize(Rez.Strings.timeToRecovery); }
}

class YaTimeFieldView extends Ui.DataField {
    var m_app = Application.getApp();
    var m_fieldSources = new [m_app.m_fieldSources.size()];
    var m_fieldSourcesCnt = 0;
    function calcLabel(i) as String {
        var ret as String = "";
        if (m_app.m_fieldCaptionVisible) {
            var src = m_fieldSources[i];
            if (src != null) {
                ret = src.calcLabel(m_app.m_fieldCaption);
                if (ret.length() == 0) {
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
        var inversed = true;
        if (backColor != Graphics.COLOR_BLACK) {
            foreColor = Graphics.COLOR_BLACK;
            inversed = false;
        }
        dc.setColor(foreColor, backColor);
        dc.setAntiAlias(m_app.m_antiAliasing);
        dc.clear();
        dc.setColor(foreColor, Graphics.COLOR_TRANSPARENT);

        var w = dc.getWidth();
        var h = dc.getHeight();

        //как можно больше полей из m_fieldSources упихать в данное нам место
        //не отказываясь от большого шрифта
        var drawContext = new DrawContext(dc, foreColor, backColor, inversed);
        if (w <= HALF_WIDTH || m_fieldSourcesCnt == 1) {
            //самый простой случай - HALF_WIDTHх93 и/или только одно поле
            m_fieldSources[0].onUpdate(drawContext, 0, 0, w, h, calcLabel(0));
        } else if (h == FULL_HEIGHT) { // несколько линий
            for(var i = 0; i < m_fieldSourcesCnt; i++) {
                var minY = i * h/m_fieldSourcesCnt;
                var maxY = (i + 1) * h/m_fieldSourcesCnt;
                m_fieldSources[i].onUpdate(drawContext, 0, minY + 1, w, h/m_fieldSourcesCnt - 1, calcLabel(i));
                if (i < m_fieldSourcesCnt - 1) { dc.drawLine(0, maxY, w, maxY); } //horz
            }
        } else if (h >= THIRD_HEIGHT || (h >= FOURTH_HEIGHT && !m_app.m_fieldCaptionVisible)) {
            //все влезут
            if (m_fieldSourcesCnt == 4) { //2x2
                m_fieldSources[0].onUpdate(drawContext, 0, 0, w/2 - 1, h/2 - 1, calcLabel(0));
                m_fieldSources[1].onUpdate(drawContext, w/2 + 1, 0, w/2 - 1, h/2 - 1, calcLabel(1));
                m_fieldSources[2].onUpdate(drawContext, 0, h/2 + 1, w/2 - 1, h/2 - 1, calcLabel(2));
                m_fieldSources[3].onUpdate(drawContext, w/2 + 1, h/2 + 1, w/2 - 1, h/2 - 1, calcLabel(3));
                dc.drawLine(w/2, 0, w/2, h); //vert
            } else if (m_fieldSourcesCnt == 3) { // 1+2
                m_fieldSources[0].onUpdate(drawContext, 0, 0, w, h/2 - 1, calcLabel(0));
                m_fieldSources[1].onUpdate(drawContext, 0, h/2 + 1, w/2 - 1, h/2 - 1, calcLabel(1));
                m_fieldSources[2].onUpdate(drawContext, w/2 + 1, h/2 + 1, w/2 - 1, h/2 - 1, calcLabel(2));
                dc.drawLine(w/2, h/2, w/2, h); //vert
            } else { // 1+1
                m_fieldSources[0].onUpdate(drawContext, 0, 0, w, h/2 - 1, calcLabel(0));
                m_fieldSources[1].onUpdate(drawContext, 0, h/2 + 1, w, h/2 - 1, calcLabel(1));
            }
            dc.drawLine(0, h/2, w, h/2); //horz
        } else {
            //тут вместим 2
            m_fieldSources[0].onUpdate(drawContext, 0, 0, w/2 - 1, h, calcLabel(0));
            m_fieldSources[1].onUpdate(drawContext, w/2 + 1, 0, w/2 - 1, h, calcLabel(1));
            dc.drawLine(w/2, 0, w/2, h); //vert
        }
    }
    function rebuildSources() {
        var j = 0;
        for(var i = 0; i < m_app.m_fieldSources.size(); i++) {
            var newSrc = sourceFactory(m_app.m_fieldSources[i]);
            if (newSrc != null) {
               m_fieldSources[j] = newSrc;
               j++;
            }
        }
        if (j == 0) {
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
            case SK_timerTime:       return new TimerSource();
            case SK_clockTime:       return new ClockSource();
            case SK_elapsedTime:     return new ElapsedSource();
            case SK_timeLeft:        return new TimeLeftSource();
            case SK_lapTime:         return new LapTimeSource();
            case SK_avgLapTime:      return new AvgLapTimeSource();
            case SK_timeBehind:      return new TimeBehindSource();
            case SK_workoutDuration: return new WorkoutDurationSource();
            case SK_timeToGo:        return new TimeToGoSource();
            case SK_stepTime:        return new StepTimeSource();
            case SK_timeToRecovery:  return new TimeToRecoverySource();
            default:                 return null;
        }
    }
    function compute(info as Activity.Info) {
        for(var i = 0; i < m_app.m_fieldSources.size(); i++) {
            var src = m_fieldSources[i];
            if (src == null) { break; }
            src.onCompute(info);
        }
    }
}
