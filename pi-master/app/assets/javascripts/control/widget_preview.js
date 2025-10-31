if (typeof(window['pi']) != 'function') {
    window['pi'] = function() {
        window['pi'].commands = (window['pi'].commands || []);
        window['pi'].commands.push(arguments);
    }
}
window['pi'].commands = (window['pi'].commands || []);

pi('debug', true);
pi('preview', true);
pi('spa', false);

const configs = document.getElementById('widget_preview_configs').dataset;
pi('host', configs.host);
pi('identify', configs.identifier);
