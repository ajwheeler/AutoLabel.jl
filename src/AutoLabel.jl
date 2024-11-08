module AutoLabel

using IJulia, PromptingTools

function get_labels(code)
    msg =
        """You will be given a piece of code that creates a plot using either matplotlib in Python or PyPlot/PythonPlot in Julia. Your task is to analyze the code and add axis labels if they are missing. Follow these steps:

        1. Examine the following code:
        <code>
        """ *
        code *
        """
        </code>

        3. Check if the code already includes axis labels using functions like xlabel(), ylabel(), or similar.

        4. If either the x-axis or y-axis label is missing, add the appropriate labeling code. Use the variable names if the context doesn't provide more specific label names, and if not possible, don't do anything.

        5. For simple plots (no subplots), use
           plt.xlabel("X-axis label")
           plt.ylabel("Y-axis label")
        This will work in both languages. Make sure to use double quotes, since single quotes are for characters in Julia.

        6. If both labels are already present, no changes are needed.

        7. Output the code to add the labels (if any) alone. Do not output anything else.  """

    aigenerate(PromptingTools.AnthropicSchema(), msg; model="claudeh", api_key=ENV["ANTHROPIC_API_KEY"])
end

function autolabel_current_cell()
    current_cell = IJulia.In[IJulia.n]
    all_lines = split(current_cell, "\n")
    if startswith(all_lines[end], "#label")
        comment_dropped = join(all_lines[1:end-1], "\n")

        response = get_labels(comment_dropped)
        new_code = if isnothing(response.content)
            "\n#label\n# autolabel failed (delete this line to try again)"
        else
            "\n# LLM generated\n" * response.content
        end

        IJulia.load_string(comment_dropped * new_code, true)
    end
end

enable_autolabel() = IJulia.push_preexecute_hook(autolabel_current_cell)
disable_autolabel() = IJulia.pop_preexecute_hook(autolabel_current_cell)

# Only enable when running in IJulia
function __init__()
    if isdefined(Main, :IJulia) && Main.IJulia.inited
        enable_autolabel()
    else
        @warn "AutoLabel is not running in IJulia. Not enabling."
    end
end

end  # module
