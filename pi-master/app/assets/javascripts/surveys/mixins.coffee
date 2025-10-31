# Mixins from the coffescript cookbook
# Used to break down the class implementation in multiple files
#

extend = (obj, mixin) ->
  obj[name] = method for name, method of mixin
  obj

window.PulseInsightsInclude = (klass, mixin) ->
  extend klass.prototype, mixin
