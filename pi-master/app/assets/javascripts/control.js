//= require jquery3
//= require jquery_ujs
//= require jquery-ui
//= require colpick
//= require patched/stupidtable
//= require watcher

//= require bootstrap/transition
//= require bootstrap/collapse
//= require bootstrap/dropdown
//= require bootstrap/alert
//= require bootstrap/tab
//= require bootstrap/tooltip
//= require bootstrap/modal

//= require bootstrap/datepicker
//= require bootstrap/datetimepicker


//= require_tree ./control/ext
//= require_tree ./admin

//= require control/accounts
//= require control/tags
//= require select2.full.min
//= require control/get_code_snippet

//= require jquery.chained
//= require chosen-jquery

// Custom Card
//= require codemirror
//= require codemirror_css
//= require cm-resize
//= require formatting
//= require xml
//= require javascript
//= require css
//= require htmlmixed
//= require summernote.min
//= require custom_card
//= require spin.min

//= require datatables.min
//= require dataTables.buttons.min

//= require control/theme
//= require control/automations
//= require control/page_events
//= require control/localization

$.extend({
    formatNumber: function(rawNumber, decimal, delimiter) {
        decimal = typeof decimal !== 'undefined' ? decimal : 0;
        delimiter = typeof delimiter !== 'undefined' ? delimiter : ',';
        rawNumber = rawNumber.toString().replace(new RegExp(delimiter, 'g'),'');

        var temp;
        if (rawNumber == '') {
            temp = 0.0.toFixed(decimal);
        } else {
            temp = parseFloat(rawNumber).toFixed(decimal);
            if (isNaN(temp)) temp = 1000.0.toFixed(decimal);
        }
        var partArray = temp.toString().split(".");
        partArray[0] = partArray[0].toString().replace(/\B(?=(\d{3})+(?!\d))/g, delimiter);
        return partArray.join(".");
    },

    debounce: function(func, wait, immediate) {
        var timeout;
        return function() {
            var context = this,
                args = arguments;
            var later = function() {
                timeout = null;
                if (!immediate) func.apply(context, args);
            };
            var callNow = immediate && !timeout;
            clearTimeout(timeout);
            timeout = setTimeout(later, wait);
            if (callNow) func.apply(context, args);
        };
    },

    gUid: function() {
        function s4() {
            return Math.floor((1 + Math.random()) * 0x10000).toString(16).substring(1);
        }

        return s4() + s4() + '-' + s4() + '-' + s4() + '-' + s4() + '-' + s4() + s4() + s4();
    }
});
