local strings = {
    ["SI_MATSAVPRC_SAVING"] = "Materialpreise zusparen …",
}

-- Overwrite English strings
for stringId, value in pairs(strings) do
    MATSAVPRC_STRINGS[stringId] = value
end