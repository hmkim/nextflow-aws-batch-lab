nextflow.enable.dsl = 2

params.greeting = 'hello'
params.addressee = null

if (!params.addressee) exit 1, "required parameter 'addressee' missing"

process Greet {
    publishDir '/mnt/workflow/pubdir'
    input:
        val greeting
        val addressee
    output:
        path "output", emit: output_file
    script:
        """
        echo "${greeting} ${addressee}" | tee output
        """
}

workflow {
    Greet(params.greeting, params.addressee)
}
