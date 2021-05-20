# LibAddonMenuOrderListBox
An order list box widget for the ESO library LibAddonMenu-2.0

--[[orderListBoxData = {
    type = "orderlistbox",
    name = "My OrderListBox", -- or string id or function returning a string
    listEntries = {
        [1] = {
            value = "Value of the entry", -- or number or boolean or function returning the value of this entry
            uniqueKey = 1, --number of the unique key of this list entry. This will not change if the order changes. Will be used to identify the entry uniquely
            text  = "Text of this entry", -- or string id or function returning a string (optional)
            tooltip = "Tooltip text shown at this entry", -- or string id or function returning a string (optional)
        },
        [2] = {...},
        ...
    },
    getFunc = function() return db.currentSortedListEntries end,
    setFunc = function(currentSortedListEntries) db.currentSortedListEntries = currentSortedListEntries doStuff() end,
    tooltip = "OrderListBox's tooltip text.", -- or string id or function returning a string (optional)
    width = "full", -- or "half" (optional)
    minHeight = function() return db.minHeightNumber end, --or number for the minimum height of this control. Default: 26 (optional)
    maxHeight = function() return db.maxHeightNumber end, --or number for the maximum height of this control. Default: 4 * minHeight (optional)
    disabled = function() return db.someBooleanSetting end, -- or boolean (optional)
    warning = "May cause permanent awesomeness.", -- or string id or function returning a string (optional)
    requiresReload = false, -- boolean, if set to true, the warning text will contain a notice that changes are only applied after an UI reload and any change to the value will make the "Apply Settings" button appear on the panel which will reload the UI when pressed (optional)
    default = defaults.var, -- default value or function that returns the default value (optional)
    helpUrl = "https://www.esoui.com/portal.php?id=218&a=faq", -- a string URL or a function that returns the string URL (optional)
    reference = "MyAddonOrderListBox" -- unique global reference to control (optional)
} ]]
