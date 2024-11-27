local GuiVisualizer = {}

function GuiVisualizer:GradientProgressBar(UIGradient,MaxAmount,CurrentAmount)
    -- Normalize current amount (range: 0 to 1)
    local progress = math.clamp(CurrentAmount / MaxAmount, 0, 1)
    -- Create the NumberSequence for the gradient transparency
    local transparencySequence = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0), -- Fully opaque at 0%
        NumberSequenceKeypoint.new(progress, 0), -- Fully opaque at the current progress
        NumberSequenceKeypoint.new(math.clamp(progress + 0.01,0,1), 1), -- Transition to fully transparent
        NumberSequenceKeypoint.new(1, 1) -- Fully transparent at 100%
    })

    UIGradient.Transparency = transparencySequence
end

return GuiVisualizer