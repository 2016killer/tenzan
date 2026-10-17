if CLIENT then
    Tenzan = Tenzan or {}

    local test_mul = 1

    local function calculateLightningLightIntensity(t, average, jitterFrequency, jitterAmplitude, burstPeriod, burstAmplitude, burstDuration)
        local w = math.pi * 2 * jitterFrequency * t

        local jitterWave = (
            0.65 * math.sin(w + 0.4)
            + 0.35 * math.sin(w * 1.61803398875 + 2.7)
        )

        local burstWave = (
            0.65 * math.sin(w * 1.27201964951 + 1.9)
            + 0.80 * math.sin(w * 1.90211303259 + 4.1)
        ) / 1.45

        local burstTime = t % burstPeriod
        local burstEnvelope = 0

        if burstTime < burstDuration then
            local u = burstTime / burstDuration
            burstEnvelope = math.sin(math.pi * u) ^ 2
        end

        return average
            + jitterAmplitude * jitterWave
            + burstAmplitude * burstEnvelope * burstWave
    end

    local REFERENCE_INTENSITY = 2.0
    local JITTER_FREQUENCY = 10.0
    local JITTER_AMPLITUDE_REF = 0.3
    local BURST_PERIOD = 0.5
    local BURST_AMPLITUDE_REF = 0.85
    local BURST_DURATION = 0.3

    function Tenzan.GetLightningLightIntensity(AverageIntensity)
        local jitterAmplitude =
            JITTER_AMPLITUDE_REF / REFERENCE_INTENSITY * AverageIntensity

        local burstAmplitude =
            BURST_AMPLITUDE_REF / REFERENCE_INTENSITY * AverageIntensity

        return calculateLightningLightIntensity(
            RealTime(),
            AverageIntensity,
            JITTER_FREQUENCY,
            jitterAmplitude,
            BURST_PERIOD,
            burstAmplitude,
            BURST_DURATION
        )
    end


    -- local test_colorVec = Vector(1.0, 0.95, 0.4)
    -- local test_material = Material("tenzan/light_horizontal")
    -- hook.Add("PostDrawTranslucentRenderables", "paintsprites", function()
    --     test_mul = Tenzan.GetLightningLightIntensity(2)

    --     test_material:SetVector("$color", test_colorVec * test_mul)

    --     render.SetMaterial(test_material)
    --     render.DrawSprite(vector_origin, 900, 300, test_colorVec * test_mul)
    -- end)
end
