.pragma library

// Appends a note to a setting's explanation when config.ini holds a value its control
// does not offer.
function explain(info, options, value, customLabel) {
    return options.some(option => option.value === value) ? info : info + " Set to " + customLabel + " in config.ini.";
}
