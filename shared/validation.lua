W2F.Shared.Validation = {}
function W2F.Shared.Validation.assertConfig()
    assert(Config and Config.Framework, 'Config.Framework is required')
    assert(Config.Death and Config.Death.bleedoutSeconds > 0, 'Config.Death.bleedoutSeconds must be > 0')
end
