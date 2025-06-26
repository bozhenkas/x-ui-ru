const oneMinute = 1000 * 60; // Количество миллисекунд в одной минуте
const oneHour = oneMinute * 60; // Количество миллисекунд в одном часе
const oneDay = oneHour * 24; // Количество миллисекунд в одном дне
const oneWeek = oneDay * 7; // Количество миллисекунд в одной неделе
const oneMonth = oneDay * 30; // Количество миллисекунд в одном месяце

/**
 * Уменьшить на количество дней
 *
 * @param days Количество дней для уменьшения
 */
Date.prototype.minusDays = function (days) {
    return this.minusMillis(oneDay * days);
};

/**
 * Увеличить на количество дней
 *
 * @param days Количество дней для увеличения
 */
Date.prototype.plusDays = function (days) {
    return this.plusMillis(oneDay * days);
};

/**
 * Уменьшить на количество часов
 *
 * @param hours Количество часов для уменьшения
 */
Date.prototype.minusHours = function (hours) {
    return this.minusMillis(oneHour * hours);
};

/**
 * Увеличить на количество часов
 *
 * @param hours Количество часов для увеличения
 */
Date.prototype.plusHours = function (hours) {
    return this.plusMillis(oneHour * hours);
};

/**
 * Уменьшить на количество минут
 *
 * @param minutes Количество минут для уменьшения
 */
Date.prototype.minusMinutes = function (minutes) {
    return this.minusMillis(oneMinute * minutes);
};

/**
 * Увеличить на количество минут
 *
 * @param minutes Количество минут для увеличения
 */
Date.prototype.plusMinutes = function (minutes) {
    return this.plusMillis(oneMinute * minutes);
};

/**
 * Уменьшить на миллисекунды
 *
 * @param millis количество миллисекунд для уменьшения
 */
Date.prototype.minusMillis = function(millis) {
    let time = this.getTime() - millis;
    let newDate = new Date();
    newDate.setTime(time);
    return newDate;
};

/**
 * Увеличить на миллисекунды
 *
 * @param millis количество миллисекунд для увеличения
 */
Date.prototype.plusMillis = function(millis) {
    let time = this.getTime() + millis;
    let newDate = new Date();
    newDate.setTime(time);
    return newDate;
};

/**
 * Установить время на 00:00:00.000 текущего дня
 */
Date.prototype.setMinTime = function () {
    this.setHours(0);
    this.setMinutes(0);
    this.setSeconds(0);
    this.setMilliseconds(0);
    return this;
};

/**
 * Установить время на 23:59:59.999 текущего дня
 */
Date.prototype.setMaxTime = function () {
    this.setHours(23);
    this.setMinutes(59);
    this.setSeconds(59);
    this.setMilliseconds(999);
    return this;
};

/**
 * Форматировать дату
 */
Date.prototype.formatDate = function () {
    return this.getFullYear() + "-" + addZero(this.getMonth() + 1) + "-" + addZero(this.getDate());
};

/**
 * Форматировать время
 */
Date.prototype.formatTime = function () {
    return addZero(this.getHours()) + ":" + addZero(this.getMinutes()) + ":" + addZero(this.getSeconds());
};

/**
 * Форматировать дату и время
 *
 * @param split разделитель между датой и временем, по умолчанию пробел
 */
Date.prototype.formatDateTime = function (split = ' ') {
    return this.formatDate() + split + this.formatTime();
};

class DateUtil {

    // Преобразовать строку в объект Date
    static parseDate(str) {
        return new Date(str.replace(/-/g, '/'));
    }

    static formatMillis(millis) {
        return moment(millis).format('YYYY-M-D H:m:s')
    }

    static firstDayOfMonth() {
        const date = new Date();
        date.setDate(1);
        date.setMinTime();
        return date;
    }
}