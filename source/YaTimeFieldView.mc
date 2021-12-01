import Toybox.Activity;
import Toybox.Lang;
import Toybox.Time;
import Toybox.Graphics;
using Toybox.Time.Gregorian;
using Toybox.WatchUi as Ui;
using Toybox.System as Sys;

//для тестирования (в релизе поставить всё по 0)
const TEST_ADD_SECONDS as Number = 0;   // увеличить отображаемое время, чтобы отработал алгоритм показа часов, например
const TEST_REMAINS as Boolean = false;  // тест прогноза времени финиша
const TEST_RECTS as Boolean = false;    // тест вычислений координат

enum SourceKind { SK_timerTime, SK_clockTime, SK_elapsedTime, SK_timeLeftFin, SK_timeLeftNxt, SK_lapTime, SK_avgLapTime, SK_timeBehind, SK_workoutDuration,
    SK_timeToGo, SK_stepTime, SK_timeToRecovery }
enum TimeFlow { TF_UNKNOWN, TF_INCREASES, TF_DECREASES, TF_PAUSED, TF_STOPPED }
enum ArrowDirection { AD_UP, AD_DOWN, AD_LEFT, AD_RIGHT } // относительно системы координат устройства
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
    var m_seconds as Number = 0, m_minutes as Number = 0, m_hours as Number = 0;
    var m_shouldShowHour as Boolean = false; //полезно, если 0 часов все-таки лучше нарисовать, чем откинуть (время суток, например)
    function setTotalSeconds(totalSeconds as Number) as Void {
        totalSeconds += TEST_ADD_SECONDS;
        m_seconds = (totalSeconds % 60).toNumber();
        var totalMinutes = (totalSeconds / 60).toLong();
        m_minutes = (totalMinutes % 60).toNumber();
        m_hours = (totalMinutes / 60).toNumber();
    }
}

class DrawContext {
    var m_dc as Graphics.Dc, m_foreColor as Graphics.ColorValue, m_backColor as Graphics.ColorValue, m_inversed as Boolean;
    function initialize(dc as Graphics.Dc, foreColor as Graphics.ColorValue, backColor as Graphics.ColorValue, inversed as Boolean) {
        m_dc = dc; m_foreColor = foreColor; m_backColor = backColor; m_inversed = inversed;
    }
}

class DigitPainterBase {
    var m_drawContext as DrawContext, m_flow as TimeFlow = TF_UNKNOWN;
    var m_x as Number, m_y as Number, m_w as Number, m_h as Number; //rectangle in field coordinates
    var m_digitGap as Number = 2, m_digitWidth as Number = 1, m_curPosition as Number = 0;
    var m_markSize as Number = 6;

    var m_timeObj as TimeObj, m_digits as Number = 6, m_delimiters as Number = 2;
    var m_bPrintSeconds as Boolean = true;
    var m_bPrintHoursd as Boolean = true;
    var m_bPrintHours as Boolean = true;

    function initialize(timeObj as TimeObj, drawContext as DrawContext, x as Number, y as Number, w as Number, h as Number) {
        m_timeObj = timeObj;
        m_drawContext = drawContext;
        m_x = x; m_y = y; m_w = w; m_h = h;
    }
    function calcArrowDirection(rotation as WhereIsUp) as ArrowDirection {
        var ret = AD_UP;
        switch (rotation) {
            case UP_IS_LEFT:
                ret = (m_flow == TF_DECREASES) ? AD_RIGHT : AD_LEFT;
                break;
            case UP_IS_RIGHT:
                ret = (m_flow == TF_INCREASES) ? AD_RIGHT : AD_LEFT;
                break;
            default: //normal
                if (m_flow == TF_DECREASES) { ret = AD_DOWN; }
                break;
        }
        return ret;
    }
    function drawFlowMarks(cx as Number, cy as Number, half_dist as Number, isBlink as Boolean, rotation as WhereIsUp) as Void {
        if (isBlink) { m_drawContext.m_dc.setPenWidth(3); }
        var wingSize = m_markSize / 2;
        if (m_flow == TF_INCREASES || m_flow == TF_DECREASES) {
            var arrowDirection = calcArrowDirection(rotation);
            switch (arrowDirection) {
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
        } else if (m_flow == TF_PAUSED) {
            switch (rotation) {
                case UP_IS_LEFT: case UP_IS_RIGHT:
                    m_drawContext.m_dc.drawLine(cx - m_markSize, cy + wingSize, cx + m_markSize, cy + wingSize);
                    m_drawContext.m_dc.drawLine(cx - m_markSize, cy - wingSize, cx + m_markSize, cy - wingSize);
                    break;
                default: //normal
                    m_drawContext.m_dc.drawLine(cx - wingSize, cy + m_markSize, cx - wingSize, cy - m_markSize);
                    m_drawContext.m_dc.drawLine(cx + wingSize, cy + m_markSize, cx + wingSize, cy - m_markSize);
                    break;
            }
        } else if (m_flow == TF_STOPPED) {
            m_drawContext.m_dc.drawRectangle(cx - wingSize - 1, cy - wingSize - 1, 2 * (wingSize + 1), 2 * (wingSize + 1));
        }
        if (isBlink) { m_drawContext.m_dc.setPenWidth(1); }
    }
    function drawDigit(digit as Number) as Void {
        m_curPosition += (m_digitWidth + m_digitGap);
    }
    function drawDelimiter(isBlink as Boolean) as Void {
        m_curPosition += (m_markSize + m_digitGap);
    }

    function drawAllDigits(flow as TimeFlow, isBlink as Boolean) as Void {
        if (TEST_RECTS) {
            m_drawContext.m_dc.drawRectangle(m_x, m_y, m_w, m_h);
            m_drawContext.m_dc.drawLine(m_x, m_y, m_x + m_w, m_y + m_h);
        }
        m_flow = flow;
        var digit = (m_timeObj.m_hours / 10).toNumber();
        if (m_bPrintHoursd) { drawDigit(digit); }
        if (m_bPrintHours) {
            digit = (m_timeObj.m_hours % 10).toNumber();
            drawDigit(digit);
            drawDelimiter(isBlink);
        }
        digit = (m_timeObj.m_minutes / 10).toNumber();
        drawDigit(digit);
        digit = (m_timeObj.m_minutes % 10).toNumber();
        drawDigit(digit);
        if (m_bPrintSeconds) {
            drawDelimiter(isBlink);
            digit = (m_timeObj.m_seconds / 10).toNumber();
            drawDigit(digit);
            digit = (m_timeObj.m_seconds % 10).toNumber();
            drawDigit(digit);
        } else if (m_bPrintHours && isBlink) {
            notifySecondsHidden(); 
        }
    }
    function drawProgress(percent as Number) as Void {
        if (m_w > m_h) {
            m_drawContext.m_dc.fillRectangle(m_x + 1, m_y + 1, percent * (m_w - 2) / 100, m_h - 2);
        } else {
            m_drawContext.m_dc.fillRectangle(m_x + 1, m_y + 1, m_w - 2, percent * (m_h - 2) / 100);
        }
    }
    function notifySecondsHidden() as Void {}
}
typedef NA as Array<Number>;
class DigitPainterVectorBase extends DigitPainterBase {
    //4x6 matrix
    const SegmentDict as Dictionary<Number, Array<NA> > = {
        0 => [[1,0, 3,0] as NA, [3,0, 4,1] as NA, [4,1, 4,5] as NA, [4,5, 3,6] as NA, [3,6, 1,6] as NA, [1,6, 0,5] as NA, [0,5, 0,1] as NA, [0,1, 1,0] as NA] as Array<NA>,
        1 => [[1,0, 3,0] as NA, [2,0, 2,6] as NA, [2,6, 1,5] as NA] as Array<NA>, 
        2 => [[0,5, 1,6] as NA, [1,6, 3,6] as NA, [3,6, 4,5] as NA, [4,5, 4,4] as NA, [4,4, 3,3] as NA, [3,3, 1,3] as NA, [1,3, 0,2] as NA, [0,2, 0,0] as NA, [0,0, 4,0] as NA] as Array<NA>, 
        3 => [[0,5, 1,6] as NA, [1,6, 3,6] as NA, [3,6, 4,5] as NA, [4,5, 4,4] as NA, [4,4, 3,3] as NA, [3,3, 2,3] as NA, [3,3, 4,2] as NA, [4,2, 4,1] as NA, [4,1, 3,0] as NA, [3,0, 1,0] as NA, [1,0, 0,1] as NA] as Array<NA>, 
        4 => [[3,0, 3,6] as NA, [1,6, 0,2] as NA, [0,2, 4,2] as NA] as Array<NA>,
        5 => [[0,1, 1,0] as NA, [1,0, 3,0] as NA, [3,0, 4,1] as NA, [4,1, 4,3] as NA, [4,3, 3,4] as NA, [3,4, 0,4] as NA, [0,4, 0,6] as NA, [0,6, 4,6] as NA] as Array<NA>,
        6 => [[3,6, 2,6] as NA, [2,6, 0,4] as NA, [0,4, 0,1] as NA, [0,1, 1,0] as NA, [1,0, 3,0] as NA, [3,0, 4,1] as NA, [4,1, 4,2] as NA, [4,2, 3,3] as NA, [3,3, 0,3] as NA] as Array<NA>,
        7 => [[1,0, 4,6] as NA, [4,6, 0,6] as NA, [2,3, 3,3] as NA] as Array<NA>,
        8 => [[1,3, 0,2] as NA, [0,2, 0,1] as NA, [0,1, 1,0] as NA, [1,0, 3,0] as NA, [3,0, 4,1] as NA, [4,1, 4,2] as NA, [4,2, 3,3] as NA, [3,3, 1,3] as NA, [1,3, 0,4] as NA, [0,4, 0,5] as NA, [0,5, 1,6] as NA, [1,6, 3,6] as NA, [3,6, 4,5] as NA, [4,5, 4,4] as NA, [4,4, 3,3] as NA] as Array<NA>, 
        9 => [[1,0, 2,0] as NA, [2,0, 4,2] as NA, [4,2, 4,5] as NA, [4,5, 3,6] as NA, [3,6, 1,6] as NA, [1,6, 0,5] as NA, [0,5, 0,4] as NA, [0,4, 1,3] as NA, [1,3, 4,3] as NA] as Array<NA>
    };
    var m_kx as Number = 0, m_ky as Number = 0, m_penWidth as Number = 6;
    function initialize(timeObj as TimeObj, drawContext as DrawContext, x as Number, y as Number, w as Number, h as Number) {
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
    function CalcDigitWidth(space as Number) as Void {
        m_digitWidth = (space - m_digitGap * (2 + m_digits / 2 + 2 * m_delimiters) - m_delimiters * m_markSize + m_digits / 2 /*anti-round*/) / m_digits;
    }
}
class DigitPainterVectorBook extends DigitPainterVectorBase {
    function initialize(timeObj as TimeObj, drawContext as DrawContext, x as Number, y as Number, w as Number, h as Number) {
        if (w <= HALF_WIDTH) {
            m_penWidth = 5;
        } else {
            m_markSize = 8;
        }
        m_digitGap = m_markSize + 2;
        DigitPainterVectorBase.initialize(timeObj, drawContext, x, y, w, h);
        CalcDigitWidth(m_w);

        m_kx = m_digitWidth / 4;
        m_ky = (m_h - 2 * m_digitGap) / 6;
        m_curPosition = m_digitGap + m_x;

        if (m_digitWidth / m_penWidth < 2) {
            m_penWidth = m_digitWidth / 2;
        }
    }
    function drawDigit(digit as Number) as Void {
        m_drawContext.m_dc.setPenWidth(m_penWidth);
        if (digit < 0 || digit > 9) { digit = 0; }
        var lines = SegmentDict[digit.toNumber()] as Array<NA>;
        for(var i = 0; i < lines.size(); i++) {
            //each line is [x1, y1, x2, y2] in relative [0..4, 0..6] space
            var line = lines[i];
            var x1 = m_curPosition + m_kx * line[0] + 1; var x2 = m_curPosition + m_kx * line[2] + 1;
            var y1 = m_y + m_h - m_digitGap - m_ky * line[1]; var y2 = m_y + m_h - m_ky * line[3] - m_digitGap;
            m_drawContext.m_dc.drawLine(x1, y1, x2, y2);
        }
        m_drawContext.m_dc.setPenWidth(1);
        DigitPainterBase.drawDigit(digit);
        if (TEST_RECTS) {
            m_drawContext.m_dc.drawRectangle(m_curPosition, m_y, m_curPosition, m_y + m_w);
        }
    }
    function drawDelimiter(isBlink as Boolean) as Void {
        var cy = m_y + m_h / 2, cx = m_curPosition + m_markSize / 2;
        drawFlowMarks(cx, cy, m_h / 10, isBlink, UP_NORMAL);
        DigitPainterBase.drawDelimiter(isBlink);
    }
}
class DigitPainterVectorLandscape extends DigitPainterVectorBase {
    var m_flipLandscape as Boolean;
    function drawProgress(percent as Number) as Void {
        if (m_flipLandscape) {
            var nonFilledSize = (100 - percent) * (m_h - 2) / 100;
            m_drawContext.m_dc.fillRectangle(m_x + 1, nonFilledSize + m_y + 1, m_w - 2, m_h - 2 - nonFilledSize);
        } else {
            DigitPainterVectorBase.drawProgress(percent);
        }
    }
    function initialize(timeObj as TimeObj, drawContext as DrawContext, x as Number, y as Number, w as Number, h as Number) {
        m_flipLandscape = getApp().m_flipLandscape as Boolean;
        m_digitGap = w / 17;
        m_penWidth = m_digitGap / 2;
        m_markSize = m_digitGap - 2;
        DigitPainterVectorBase.initialize(timeObj, drawContext, x, y, w, h);
        CalcDigitWidth(m_h);

        m_ky = m_digitWidth / 4;
        m_kx = (m_w - 2 * m_digitGap) / 6;
        m_curPosition = m_digitGap + m_y;
    }
    function drawDigit(digit as Number) as Void {
        m_drawContext.m_dc.setPenWidth(m_penWidth);
        if (digit < 0 || digit > 9) { digit = 0; }
        var lines = SegmentDict[digit.toNumber()] as Array<NA>;
        for(var i = 0; i < lines.size(); i++) {
            //each line is [x1, y1, x2, y2] in relative [0..4, 0..6] space
            var line = lines[i] as NA;
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
        DigitPainterBase.drawDigit(digit);
        if (TEST_RECTS) {
            m_drawContext.m_dc.drawRectangle(m_x, m_curPosition, m_x + m_w, m_curPosition);
        }
    }
    function drawDelimiter(isBlink as Boolean) as Void {
        var cx = m_x + m_w / 2, cy, rotation;
        if (m_flipLandscape) {
            cy = 2 * m_y + m_h - m_curPosition - m_markSize / 2;
            rotation = UP_IS_LEFT;
        } else {
            cy = m_curPosition + m_markSize / 2;
            rotation = UP_IS_RIGHT;
        }
        drawFlowMarks(cx, cy, m_w / 10, isBlink, rotation);
        DigitPainterBase.drawDelimiter(isBlink);
    }
}
class DigitPainterFont extends DigitPainterBase {
    var m_font as Graphics.FontDefinition = Graphics.FONT_SYSTEM_NUMBER_THAI_HOT;
    function initialize(timeObj as TimeObj, drawContext as DrawContext, x as Number, y as Number, w as Number, h as Number) {
        DigitPainterBase.initialize(timeObj, drawContext, x, y, w, h);
        if (w <= HALF_WIDTH) {
            if (m_timeObj.m_hours > 9) { //no place for the seconds
                m_bPrintSeconds = false; //small square
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
            } else {
                m_font = Graphics.FONT_SYSTEM_NUMBER_MILD;
                m_digitWidth = 20;
                m_digitGap = 1;
            }
        } else {
            if (h < B3_HEIGHT) {
                m_font = Graphics.FONT_SYSTEM_NUMBER_HOT;
                m_digitWidth = 29;
            } else {
                m_digitWidth = 38;
                m_markSize = 8;
            }
        }
        var need_x = m_digitWidth * m_digits + m_digitGap * (2 + m_digits / 2 + 2 * m_delimiters) + m_delimiters * (m_markSize + 6);
        m_curPosition = x + (w - need_x) / 2 + m_digitGap; //center!
    }
    function drawDigit(digit as Number) as Void {
        if (digit < 0 || digit > 9) { digit = 0; }
        m_drawContext.m_dc.drawText(m_curPosition + m_digitWidth / 2, m_y + m_h / 2 + m_digitWidth / 7 + 3, m_font, digit.format("%d"), Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        DigitPainterBase.drawDigit(digit);
        if (m_bPrintSeconds == false) {
            m_curPosition--; // got some place for notifySecondsHidden mark
        }
        if (TEST_RECTS) {
            m_drawContext.m_dc.drawRectangle(m_curPosition, m_y, m_curPosition, m_y + m_w);
        }
    }
    function notifySecondsHidden() as Void {
        m_drawContext.m_dc.drawRectangle(m_curPosition, m_y + m_h / 2 - m_digitWidth / 7 + 3, 3, 3);
    }
    function drawDelimiter(isBlink as Boolean) as Void {
        var cx = m_curPosition + m_markSize / 2 + 3, cy = m_y + m_h / 2;
        drawFlowMarks(cx, cy, m_digitWidth / 6, isBlink, UP_NORMAL);
        DigitPainterBase.drawDelimiter(isBlink);
        m_curPosition += 6;
    }
}

class BaseSource {
    var m_defLabelId as Symbol, m_defLabelSuffix as String = "";
    var m_timeObj as TimeObj = new TimeObj();
    var m_flow as TimeFlow = TF_UNKNOWN;

    static function SafeNumber(num as Number?) as Number { return (num == null) ? 0 : (num as Number); }
    static function SafeFloat(num as Float?) as Float { return (num == null) ? 0.0 : (num as Float); }
    static function SafeString(str as String?) as String { return (str == null) ? "" : (str as String); }

    function initialize(defLabelId as Symbol) { m_defLabelId = defLabelId; }
    function calcLabel(fieldCaption as String) as String {
        if (fieldCaption.length() == 0) {
            fieldCaption = Ui.loadResource(m_defLabelId) + m_defLabelSuffix;
        }
        return fieldCaption;
    }
    function onCompute(info as Activity.Info) as Void {}
    function onTimerLap() as Void {}
    function onTimerReset() as Void {}
    function preDrawTime(painter as DigitPainterBase, isBlink as Boolean) as Void {}
    function postDrawTime(painter as DigitPainterBase, isBlink as Boolean) as Void {}
    function drawContent(drawContext as DrawContext, x as Number, y as Number, w as Number, h as Number) as Void {
        var txt = "not impl";
        drawContext.m_dc.drawText(x + w/2, y + h/2,
            Graphics.FONT_SYSTEM_XTINY, txt, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        drawContext.m_dc.drawRoundedRectangle(x + 1, y + 1, w - 2, h - 2, 5);
    }
    function onUpdate(drawContext as DrawContext, x as Number, y as Number, w as Number, h as Number, label as String) as Void {
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
    function drawTime(drawContext as DrawContext, x as Number, y as Number, w as Number, h as Number) as Void {
        var p = (h > w) ? 
            new DigitPainterVectorLandscape(m_timeObj, drawContext, x, y, w, h) : 
                getApp().m_forceVectorFont ? new DigitPainterVectorBook(m_timeObj, drawContext, x, y, w, h) :
                                             new DigitPainterFont(m_timeObj, drawContext, x, y, w, h);
        var isBlink = (Time.now().value() & 1) != 0;
        preDrawTime(p, isBlink);
        p.drawAllDigits(m_flow, isBlink);
        postDrawTime(p, isBlink);
    }
}
class TimerSource extends BaseSource {
    var m_lastTimeVal as Number = 0;
    function actInfoToTimeFlow(timeVal as Number, info as Activity.Info) as TimeFlow {
        if (info == null) { return TF_UNKNOWN; }
        var ts = SafeNumber(info.timerState);
        if (ts == null || ts == Activity.TIMER_STATE_OFF) { return TF_UNKNOWN; }
        
        var ret = TF_PAUSED;
        if(timeVal > m_lastTimeVal) {
            ret = TF_INCREASES;
        } else if(timeVal < m_lastTimeVal) {
            ret = TF_DECREASES;
        }
        m_lastTimeVal = timeVal;
        m_timeObj.setTotalSeconds(timeVal / 1000);
        if (ts == Activity.TIMER_STATE_STOPPED) { return TF_STOPPED; }
        return ret;
    }
    function onTimerReset() as Void {
        m_lastTimeVal = 0;
        m_timeObj.setTotalSeconds(0);
        m_defLabelSuffix = "";
        m_flow = TF_UNKNOWN;
    }
    function computeBy(timeVal as Number, info as Activity.Info) as Void {
        m_flow = actInfoToTimeFlow(timeVal, info);
        if (info.startTime != null) {
            var gi = Gregorian.info(info.startTime as Time.Moment, Time.FORMAT_MEDIUM);
            m_defLabelSuffix = Lang.format(" @$1$:$2$", [ gi.hour.format("%02d"), gi.min.format("%02d") ]);
            return;
        }
        m_defLabelSuffix = "";
    }
    function onCompute(info as Activity.Info) as Void {
        computeBy(SafeNumber(info.timerTime), info);
    }
    function initialize(defLabelId as Symbol) { BaseSource.initialize(defLabelId); }
    function drawContent(drawContext as DrawContext, x as Number, y as Number, w as Number, h as Number) as Void {
        if (m_flow == TF_UNKNOWN) {
            var font = Graphics.FONT_SYSTEM_LARGE;
            var txt = "";
            if (h > HALF_HEIGHT) {
                txt = Ui.loadResource(Rez.Strings.notStartedLarge) as String; //"Timer\n\nis not\n\nstarted\n\nyet"
            } else if (h == HALF_HEIGHT) {
                txt = Ui.loadResource(Rez.Strings.notStartedMedium) as String; //"Timer is not\n\nstarted yet"
            } else if (w > HALF_WIDTH) {
                if (h < FOURTH_HEIGHT) { font = Graphics.FONT_SYSTEM_MEDIUM; }
            } else {
                font = Graphics.FONT_SYSTEM_SMALL;
            }
            if (txt.length() == 0) { txt = Ui.loadResource(Rez.Strings.notStarted) as String; } //"Timer is not\nstarted yet"
            drawContext.m_dc.drawText(x + w/2, y + h/2,
                font, txt, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            return;
        }
        drawTime(drawContext, x, y, w, h);
    }
}
class ClockSource extends BaseSource {
    function initialize() { BaseSource.initialize(Rez.Strings.clockTime); }
    function FormatUTC(offMinutes as Number) as String {
        var ret = " UTC" + (offMinutes > 0 ? "+" : "-");
        if (offMinutes < 0) { offMinutes = -offMinutes; }
        var minutes = offMinutes % 60;
        ret += (offMinutes / 60).format("%d");
        if (minutes != 0) { ret += ":" + minutes.format("%d"); }
        return ret;
    }
    function drawContent(drawContext as DrawContext, x as Number, y as Number, w as Number, h as Number) as Void {
        var ct = System.getClockTime();
        m_timeObj.m_hours = ct.hour + TEST_ADD_SECONDS / 3600;
        m_timeObj.m_minutes = ct.min;
        m_timeObj.m_seconds = ct.sec;
        m_timeObj.m_shouldShowHour = true;
        m_defLabelSuffix = FormatUTC(ct.timeZoneOffset / 60);
        m_flow = TF_INCREASES;
        drawTime(drawContext, x, y, w, h);
    }
}
class ElapsedSource extends TimerSource {
    function onCompute(info as Activity.Info) as Void {
        computeBy(SafeNumber(info.elapsedTime), info);
    }
    function initialize() { TimerSource.initialize(Rez.Strings.elapsedTime); }
}
class TimeLeftSource extends BaseSource {
    var m_distRemains as Float = 0.0, m_elapsedDistance as Float = 0.0; //meters
    var m_currentSpeed as Float = 0.0; //meters per second
    var m_oldRemainSeconds as Number = 0;
    var m_progress as Number = 0;
    function initialize(defLabelId as Symbol) {
        BaseSource.initialize(defLabelId);
        if (TEST_REMAINS) { m_distRemains = 12000.0; m_elapsedDistance = 24000.0; }
    }
    function onCompute(info as Activity.Info) as Void {
        var destName = "";
        if ($.TEST_REMAINS) {
            m_currentSpeed = 120.0;
            if (m_distRemains > 0.0) {
                m_elapsedDistance += m_currentSpeed;
                m_distRemains -= m_currentSpeed;
            }
        } else {
            m_distRemains = SafeFloat((m_defLabelId == Rez.Strings.timeLeftFin) ? info.distanceToDestination : info.distanceToNextPoint);
            destName = SafeString((m_defLabelId == Rez.Strings.timeLeftFin) ? info.nameOfDestination : info.nameOfNextPoint);
            m_currentSpeed = SafeFloat(info.currentSpeed);
            m_elapsedDistance = SafeFloat(info.elapsedDistance);
        }
        if (destName == null || destName.length() == 0) {
            destName = Ui.loadResource((m_defLabelId == Rez.Strings.timeLeftFin) ? Rez.Strings.defNameOfDestination : Rez.Strings.defNameOfNextPoint) as String;
        }

        m_progress = 0;
        m_flow = TF_DECREASES;
        if (m_distRemains == 0.0) {
            m_flow = TF_STOPPED;
            m_oldRemainSeconds = 0;
            m_timeObj.setTotalSeconds(0);
            m_defLabelSuffix = "";
        } else if (m_currentSpeed < 2.0) {
            m_flow = TF_PAUSED;
        } else {
            var newRemainSeconds = (m_distRemains / m_currentSpeed).toNumber();
            if (m_oldRemainSeconds != 0 && newRemainSeconds >= m_oldRemainSeconds) { m_flow = TF_INCREASES; }
            m_oldRemainSeconds = newRemainSeconds;
            m_timeObj.setTotalSeconds(newRemainSeconds.toNumber());
            if (m_elapsedDistance + m_distRemains > 1) {
                m_progress = (m_elapsedDistance * 100 / (m_elapsedDistance + m_distRemains)).toNumber();
                m_defLabelSuffix = Lang.format("$1$% $2$", [ 100 - m_progress, destName]);
            }
        }
    }
    function drawContent(drawContext as DrawContext, x as Number, y as Number, w as Number, h as Number) as Void {
        drawTime(drawContext, x, y, w, h);
    }
    function preDrawTime(painter as DigitPainterBase, isBlink as Boolean) as Void {
        if (m_elapsedDistance != null && m_distRemains != null) {
            //we have a progress in %
            painter.m_drawContext.m_dc.setColor( 
                (m_flow != TF_INCREASES) ? (painter.m_drawContext.m_inversed ? Graphics.COLOR_DK_GREEN : Graphics.COLOR_GREEN)
                                         : (painter.m_drawContext.m_inversed ? Graphics.COLOR_DK_RED : Graphics.COLOR_RED),
                Graphics.COLOR_TRANSPARENT);
            painter.drawProgress(m_progress);
            painter.m_drawContext.m_dc.setColor(painter.m_drawContext.m_foreColor, Graphics.COLOR_TRANSPARENT);
        }
        BaseSource.preDrawTime(painter, isBlink);
    }
}
// Среднее время круга (Avg Lap Time)
class AvgLapTimeSource extends TimerSource {
    var m_laps as Number = 1;
    function initialize(defLabelId as Symbol) { TimerSource.initialize(defLabelId); }
    function onTimerReset() as Void {
        m_laps = 1;
        TimerSource.onTimerReset();
    }
    function onTimerLap() as Void {
        m_laps++;
        m_defLabelSuffix = " @" + m_laps.toString();
    }
    function onCompute(info as Activity.Info) as Void {
        m_flow = actInfoToTimeFlow(info.timerTime != null ? ((info.timerTime as Number) / m_laps).toNumber() : 0, info);
    }
}
// Время круга (Lap Time) - недоступно в 1030, пытаемся догадаться
class LapTimeSource extends AvgLapTimeSource {
    var m_reperTime as Number = 0;
    function initialize() { AvgLapTimeSource.initialize(Rez.Strings.lapTime); }
    function onTimerReset() as Void {
        m_reperTime = 0;
        AvgLapTimeSource.onTimerReset();
    }
    function onTimerLap() as Void {
        m_lastTimeVal = 0;
        var info = Activity.getActivityInfo();
        if (info != null) {
            m_reperTime = SafeNumber((info as Activity.Info).timerTime);
        } else {
            m_reperTime = 0;
        }
        m_timeObj.setTotalSeconds(0);
        AvgLapTimeSource.onTimerLap();
    }
    function onCompute(info as Activity.Info) as Void {
        m_flow = actInfoToTimeFlow(info.timerTime != null ? (info.timerTime as Number) - m_reperTime : 0, info);
    }
}
// Время отставания (кр/зел?) от вирт. партнера (Time Behind) - не реализовано в IQ
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
    /*var m_lastTime as Number;
    function onCompute(info as Activity.Info) as Void {
        var stepObj = Activity.getCurrentWorkoutStep(); //(Lang.OperationNotAllowedException) — Thrown if called from a data field app
        var curTime as Number = 0;
        if (stepObj == null) {
            m_flow = TF_STOPPED;
        } else {
            stepObj = stepObj.step;
            if (stepObj instanceof Activity.WorkoutIntervalStep) {
                stepObj = stepObj.activeStep; //what if RestStep is now on?
            }
            if (stepObj != null && stepObj instanceof Activity.WorkoutStep) {
                if (stepObj.durationType == WORKOUT_STEP_DURATION_TIME) {
                    curTime = stepObj.durationValue;
                    if (m_lastTime > curTime) { m_flow = TF_DECREASES;} 
                    else if (m_lastTime < curTime) { m_flow = TF_INCREASES;} 
                    else { m_flow = TF_PAUSED;} 
                }
            }
        }
        m_timeObj.setTotalSeconds(curTime / 1000);
        m_lastTime = curTime;
    }
    function drawContent(drawContext as DrawContext, x as Number, y as Number, w as Number, h as Number) as Void {
        drawTime(drawContext, x, y, w, h);
    }*/
    function initialize() { BaseSource.initialize(Rez.Strings.stepTime); }
}
// Время восстановления Time To Recovery - need Api3.3.0, but for now 1030+ have 3.2.8
class TimeToRecoverySource extends BaseSource {
    function initialize() { BaseSource.initialize(Rez.Strings.timeToRecovery); }
    /*info.timeToRecovery*/
}

class YaTimeFieldView extends Ui.DataField {
    var m_app as YaTimeFieldApp = $.getApp();
    var m_fieldSources as Array<BaseSource?> = new [m_app.m_fieldSources.size()] as Array<BaseSource ?>;
    var m_fieldSourcesCnt as Number = 0;
    function calcLabel(i as Number) as String {
        var ret = "";
        if (m_app.m_fieldCaptionVisible) {
            var src = m_fieldSources[i];
            if (src != null) {
                ret = src.calcLabel(m_app.m_fieldCaption);
                if (ret.length() == 0) {
                    ret = "YaTimeField #" + i.toString();
                }
            }
        }
        return ret;
    }
    function initialize() {
        Ui.DataField.initialize();
        rebuildSources();
    }
    function onUpdate(dc as Graphics.Dc) as Void {
        try {
            onUpdateWorker(dc); 
        } catch(ex) { 
            Sys.println(Lang.format("onUpdate exception: $1$", [ex.getErrorMessage()])); 
        }
    }
    function getFieldSource(i as Number) as BaseSource {
        return m_fieldSources[i] as BaseSource;
    }
    function onUpdateWorker(dc as Graphics.Dc) as Void {
        var foreColor = Graphics.COLOR_WHITE;
        var backColor = getBackgroundColor() as Graphics.ColorValue;
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
            getFieldSource(0).onUpdate(drawContext, 0, 0, w, h, calcLabel(0));
        } else if (h == FULL_HEIGHT) { // несколько линий
            for(var i = 0; i < m_fieldSourcesCnt; i++) {
                var minY = i * h/m_fieldSourcesCnt;
                var maxY = (i + 1) * h/m_fieldSourcesCnt;
                getFieldSource(i).onUpdate(drawContext, 0, minY + 1, w, h/m_fieldSourcesCnt - 1, calcLabel(i));
                if (i < m_fieldSourcesCnt - 1) { dc.drawLine(0, maxY, w, maxY); } //horz
            }
        } else if (h >= THIRD_HEIGHT || (h >= FOURTH_HEIGHT && !m_app.m_fieldCaptionVisible)) {
            //все влезут
            if (m_fieldSourcesCnt == 4) { //2x2
                getFieldSource(0).onUpdate(drawContext, 0, 0, w/2 - 1, h/2 - 1, calcLabel(0));
                getFieldSource(1).onUpdate(drawContext, w/2 + 1, 0, w/2 - 1, h/2 - 1, calcLabel(1));
                getFieldSource(2).onUpdate(drawContext, 0, h/2 + 1, w/2 - 1, h/2 - 1, calcLabel(2));
                getFieldSource(3).onUpdate(drawContext, w/2 + 1, h/2 + 1, w/2 - 1, h/2 - 1, calcLabel(3));
                dc.drawLine(w/2, 0, w/2, h); //vert
            } else if (m_fieldSourcesCnt == 3) { // 1+2
                getFieldSource(0).onUpdate(drawContext, 0, 0, w, h/2 - 1, calcLabel(0));
                getFieldSource(1).onUpdate(drawContext, 0, h/2 + 1, w/2 - 1, h/2 - 1, calcLabel(1));
                getFieldSource(2).onUpdate(drawContext, w/2 + 1, h/2 + 1, w/2 - 1, h/2 - 1, calcLabel(2));
                dc.drawLine(w/2, h/2, w/2, h); //vert
            } else { // 1+1
                getFieldSource(0).onUpdate(drawContext, 0, 0, w, h/2 - 1, calcLabel(0));
                getFieldSource(1).onUpdate(drawContext, 0, h/2 + 1, w, h/2 - 1, calcLabel(1));
            }
            dc.drawLine(0, h/2, w, h/2); //horz
        } else {
            //тут вместим 2
            getFieldSource(0).onUpdate(drawContext, 0, 0, w/2 - 1, h, calcLabel(0));
            getFieldSource(1).onUpdate(drawContext, w/2 + 1, 0, w/2 - 1, h, calcLabel(1));
            dc.drawLine(w/2, 0, w/2, h); //vert
        }
    }
    function rebuildSources() as Void {
        var j = 0;
        try {
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
        } catch(ex) {
            Sys.println(Lang.format("$1$.rebuildSources exception: $2$", [j, ex.getErrorMessage()])); 
        }
        m_fieldSourcesCnt = j;
        for(; j < m_app.m_fieldSources.size(); j++ ) {
            m_fieldSources[j] = null;
        }
    }
    function sourceFactory(i as Number) as BaseSource? {
        switch (i) {
            case SK_timerTime:       return new TimerSource(Rez.Strings.timerTime);
            case SK_clockTime:       return new ClockSource();
            case SK_elapsedTime:     return new ElapsedSource();
            case SK_timeLeftFin:     return new TimeLeftSource(Rez.Strings.timeLeftFin);
            case SK_timeLeftNxt:     return new TimeLeftSource(Rez.Strings.timeLeftNxt);
            case SK_lapTime:         return new LapTimeSource();
            case SK_avgLapTime:      return new AvgLapTimeSource(Rez.Strings.avgLapTime);
            case SK_timeBehind:      return new TimeBehindSource();
            case SK_workoutDuration: return new WorkoutDurationSource();
            case SK_timeToGo:        return new TimeToGoSource();
            case SK_stepTime:        return new StepTimeSource();
            case SK_timeToRecovery:  return new TimeToRecoverySource();
            default:                 return null;
        }
    }
    function compute(info as Activity.Info) as Void {
        for(var i = 0; i < m_app.m_fieldSources.size(); i++) {
            var src = m_fieldSources[i];
            if (src == null) { break; }
            try { getFieldSource(i).onCompute(info); } catch(ex) {
                Sys.println(Lang.format("$1$.compute exception: $2$", [i, ex.getErrorMessage()])); 
            }
        }
    }
    function onTimerLap() as Void {
        for(var i = 0; i < m_app.m_fieldSources.size(); i++) {
            var src = m_fieldSources[i];
            if (src == null) { break; }
            try { getFieldSource(i).onTimerLap(); } catch(ex) {
                Sys.println(Lang.format("$1$.onTimerLap exception: $2$", [i, ex.getErrorMessage()])); 
            }
        }
    }
    function onTimerReset() as Void {
        for(var i = 0; i < m_app.m_fieldSources.size(); i++) {
            var src = m_fieldSources[i];
            if (src == null) { break; }
            try { getFieldSource(i).onTimerReset(); } catch(ex) {
                Sys.println(Lang.format("$1$.onTimerReset exception: $2$", [i, ex.getErrorMessage()])); 
            }
        }
    }
}

class MyInputDelegate extends Ui.InputDelegate {
    function initialize() {
        InputDelegate.initialize();
    }
    function onTap(clickEvent) {
        //Sys.println(clickEvent.getType());      // e.g. CLICK_TYPE_TAP = 0
        return true;
    }
}