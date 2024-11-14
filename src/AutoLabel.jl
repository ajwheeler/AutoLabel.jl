module AutoLabel

using IJulia, HTTP, JSON

const msg_prefix = """
You are an expert in data visualization and Python/Julia plotting libraries, particularly matplotlib 
and PyPlot.jl/PythonPlot.jl. 
Your task is to analyze plotting code and suggest appropriate axis labels based on the code context 
and variable names. Keep your responses concise and only output the necessary labeling code.
Follow these steps:

1. Examine the following code.
3. Check if the code already includes axis labels using functions like xlabel(), ylabel(), or similar.

4. If either the x-axis or y-axis label is missing, add the appropriate labeling code. 
   When in doubt, use the variable names.

5. For simple plots (no subplots), use
plt.xlabel("X-axis label")
plt.ylabel("Y-axis label")
This will work in both languages. Make sure to use double quotes, since single quotes are for characters in Julia.

6. If both labels are already present, no changes are needed.

7. Output the code to add the labels (if any) alone. Do not output anything else.  
"""

function get_labels(code)


    parsed_response = try
        response = HTTP.post(
            "https://api.anthropic.com/v1/messages",
            [
                "x-api-key" => ENV["ANTHROPIC_API_KEY"],
                "anthropic-version" => "2023-06-01",
                "content-type" => "application/json",
                #"anthropic-beta" => "prompt-caching-2024-07-31",
            ],
            JSON.json(Dict(
                "model" => "claude-3-5-haiku-latest",
                "temperature" => 0.0,
                "max_tokens" => 100,
                "system" => [
                    Dict([
                        "type" => "text",
                        "text" => msg_prefix,
                        # this doesn't do anything because we're under the minimum token count for
                        # Haiku (2048 toks)
                        #"cache_control" => Dict("type" => "ephemeral"),
                    ])
                ],
                "messages" => [
                    Dict("role" => "user", "content" => code)
                ],
            ))
        )
        JSON.parse(String(response.body))
    catch e
        if isa(e, HTTP.ExceptionRequest.StatusError)
            @warn "HTTP error occurred when calling Anthropic API: $(e)"
            return
        else
            rethrow(e)
        end
    end

    input_tokens = parsed_response["usage"]["input_tokens"]
    output_tokens = parsed_response["usage"]["output_tokens"]
    @info "API usage: $(input_tokens) input tokens, $(output_tokens) output tokens"

    parsed_response["content"][1]["text"]

end

function autolabel_current_cell()
    current_cell = IJulia.In[IJulia.n]
    all_lines = split(current_cell, "\n")
    if startswith(all_lines[end], "#label")
        comment_dropped = join(all_lines[1:end-1], "\n")

        response = get_labels(comment_dropped)
        new_code = if isnothing(response)
            "\n#label\n# AutoLabel.jl failed (delete this line to try again)"
        else
            "\n# LLM generated\n" * response
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
