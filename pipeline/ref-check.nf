nextflow.enable.dsl = 2

// Reads reference data through a Mountpoint for Amazon S3 mount on the compute
// instance instead of staging it. Requires the stack deployed with
// MOUNT_DATA_BUCKET=true and a file at s3://<DataBucket>/reference/sample.gff3.
//
// The mounted directory is passed as a `val`, not a `path`: a `path` input makes
// the head node try to stage a file that only the compute instances can see.
params.ref_dir = '/mnt/s3-ref/reference'

process REF_SUMMARY {
    input:
        val ref_dir
    output:
        path 'summary.txt'
    script:
        """
        echo "mount: \$(mount | grep -c mountpoint-s3) mountpoint-s3 filesystem(s) visible"
        ls -l ${ref_dir}
        echo "features: \$(grep -vc '^#' ${ref_dir}/sample.gff3)"
        { echo "host: \$(hostname)"; ls -l ${ref_dir}; grep -vc '^#' ${ref_dir}/sample.gff3; } > summary.txt
        """
}

workflow {
    REF_SUMMARY(params.ref_dir)
}
