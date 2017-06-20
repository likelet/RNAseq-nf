#! /usr/bin/env nextflow

// vim: syntax=groovy -*- mode: groovy;-*-

// Copyright (C) 2017 IARC/WHO

// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

params.input_folder = '.'
params.cpu          = 8
params.mem          = 50
params.mem_QC       = 2
params.fastq_ext    = "fq.gz"
params.suffix1      = "_1"
params.suffix2      = "_2"
params.ref_folder   = "ref"
params.ref          = "ref.fa"
params.output_folder   = "."
params.annot_gtf    = "Homo_sapiens.GRCh38.79.gtf"
params.GATK_folder  = "GATK"
params.GATK_bundle  = "GATK_bundle"
params.bed          = "intervals.bed"
params.RG           = "PL:ILLUMINA"
params.stranded     = "no"
params.order        = "pos"
params.hisat2_idx   = "genome_tran"
params.sjtrim       = null
params.recalibration = null
params.hisat2       = null
params.clustering   = null

params.htseq_maxreads = null //default value of htseq-count is 30000000
params.help         = null


log.info ""
log.info "--------------------------------------------------------"
log.info "  RNAseq-nf 1.0.0: alignment, QC, and reads counting workflow for whole RNA sequencing "
log.info "--------------------------------------------------------"
log.info "Copyright (C) IARC/WHO"
log.info "This program comes with ABSOLUTELY NO WARRANTY; for details see LICENSE"
log.info "This is free software, and you are welcome to redistribute it"
log.info "under certain conditions; see LICENSE for details."
log.info "--------------------------------------------------------"
log.info ""


if (params.help) {
    log.info '-------------------------------------------------------------'
    log.info ' USAGE  '
    log.info '-------------------------------------------------------------'
    log.info ''
    log.info 'nextflow run iarcbioinfo/RNAseq.nf [-with-docker] --input_folder input/ --ref_folder ref/ [OPTIONS]'
    log.info ''
    log.info 'Mandatory arguments:'
    log.info '--input_folder   FOLDER                  Folder containing BAM or fastq files to be aligned.'
    log.info '--ref_folder          FOLDER                   Folder with genome reference files (with index).'
    log.info '--output_folder     STRING                Output folder (default: results_alignment).'
    log.info '--gtf          FILE                    Annotation file.'
    log.info ""
    log.info 'Optional arguments:'
    log.info '--ref          FILE                    Reference fasta file (with index) for splice junction trimming and base recalibration.'
    log.info '    --cpu          INTEGER                 Number of cpu used by bwa mem and sambamba (default: 8).'
    log.info '    --mem          INTEGER                 Size of memory used for mapping (in GB) (default: 32).'
    log.info '    --mem_QC     INTEGER                 Size of memory used for QC and cutadapt (in GB) (default: 32).'
    log.info '    --RG           STRING                  Samtools read group specification (default : PL:ILLUMINA).'
    log.info '    --fastq_ext        STRING                Extension of fastq files (default : fq.gz)'
    log.info '    --suffix1        STRING                Suffix of fastq files 1 (default : _1)'
    log.info '    --suffix2        STRING                Suffix of fastq files 2 (default : _2)'
    log.info '    --ref_folder     STRING                Folder with reference genome and STAR index (default: ref).'
    log.info '    --bed        STRING                bed file with interval list'
    log.info '    --GATK_bundle        STRING                path to GATK bundle files (default : .)'
    log.info '    --GATK_folder        STRING                path to GATK GenomeAnalysisTK.jar file (default : .)'
    log.info '    --stranded        STRING                are reads stranded? (default : no; alternatives : yes, r)'
    log.info '    --order        STRING                how to sort reads in bam  (default : pos; alternative: name)'
    log.info '    --hisat2_idx        STRING                hisat2 index file prefix (default : genome_tran)'
    log.info ""
    log.info "Flags:"
    log.info '--sjtrim                    enable splice junction trimming'
    log.info '--recalibration                    performs base quality score recalibration (GATK)'
    log.info '--hisat2                    use hisat2 instead of STAR for reads mapping'
    log.info ''
    exit 0
}else {
  /* Software information */
  log.info "input_folder=${params.input_folder}"
  log.info "ref=${params.ref}"
  log.info "cpu=${params.cpu}"
  log.info "mem=${params.mem}"
  log.info "fastq_ext=${params.fastq_ext}"
  log.info "suffix1=${params.suffix1}"
  log.info "suffix2=${params.suffix2}"
  log.info "output_folder=${params.output_folder}"
  log.info "bed=${params.bed}"
  log.info "GATK_bundle=${params.GATK_bundle}"
  log.info "GATK_folder=${params.GATK_folder}"
  log.info "recalibration=${params.recalibration}"
  log.info "help=${params.help}"
}

//read ref files

if(params.hisat2){
	ref_1  = Channel.fromPath(params.ref_folder + params.hisat2_idx + '.1.ht2')
	ref_2  = Channel.fromPath(params.ref_folder + params.hisat2_idx + '.2.ht2')
	ref_3  = Channel.fromPath(params.ref_folder + params.hisat2_idx + '.3.ht2')
	ref_4  = Channel.fromPath(params.ref_folder + params.hisat2_idx + '.4.ht2')
	ref_5  = Channel.fromPath(params.ref_folder + params.hisat2_idx + '.5.ht2')
	ref_6  = Channel.fromPath(params.ref_folder + params.hisat2_idx + '.6.ht2')
	ref_7  = Channel.fromPath(params.ref_folder + params.hisat2_idx + '.7.ht2')
	ref_8  = Channel.fromPath(params.ref_folder + params.hisat2_idx + '.8.ht2')
	ref    = ref_1.concat( ref_2,ref_3,ref_4,ref_5,ref_6,ref_7,ref_8)
}else{
	ref_1  = Channel.fromPath(params.ref_folder +'/chrStart.txt')
	ref_2  = Channel.fromPath(params.ref_folder +'/chrNameLength.txt')
	ref_3  = Channel.fromPath(params.ref_folder +'/chrName.txt')
	ref_4  = Channel.fromPath(params.ref_folder +'/chrLength.txt')
	ref_5  = Channel.fromPath(params.ref_folder +'/exonGeTrInfo.tab')
	ref_6  = Channel.fromPath(params.ref_folder +'/exonInfo.tab')
	ref_7  = Channel.fromPath(params.ref_folder +'/geneInfo.tab')
	ref_8  = Channel.fromPath(params.ref_folder +'/Genome')
	ref_9  = Channel.fromPath(params.ref_folder +'/genomeParameters.txt')
	ref_10 = Channel.fromPath(params.ref_folder +'/SA')
	ref_11 = Channel.fromPath(params.ref_folder +'/SAindex')
	ref_12 = Channel.fromPath(params.ref_folder +'/sjdbInfo.txt')
	ref_13 = Channel.fromPath(params.ref_folder +'/transcriptInfo.tab')
	ref_14 = Channel.fromPath(params.ref_folder +'/sjdbList.fromGTF.out.tab')
	ref_15 = Channel.fromPath(params.ref_folder +'/sjdbList.out.tab')
	ref    = ref_1.concat( ref_2,ref_3,ref_4,ref_5,ref_6,ref_7,ref_8,ref_9,ref_10,ref_11,ref_12,ref_13,ref_14,ref_15)
}

annot_gtf = file(params.annot_gtf)

//read files
mode = 'fastq'
if (file(params.input_folder).listFiles().findAll { it.name ==~ /.*${params.fastq_ext}/ }.size() > 0){
    println "fastq files found, proceed with alignment"
}else{
    if (file(params.input_folder).listFiles().findAll { it.name ==~ /.*bam/ }.size() > 0){
        println "BAM files found, proceed with realignment"; mode ='bam'; files = Channel.fromPath( params.input_folder+'/*.bam' )
    }else{
        println "ERROR: input folder contains no fastq nor BAM files"; System.exit(0)
    }
}

if(mode=='bam'){
    process bam2fastq {
        cpus '1'
        memory params.mem_QC+'G'
        tag { file_tag }
        
        input:
        file infile from files
     
        output:
	val(file_tag)
	set file("${file_tag}_1.fq.gz"), file("${file_tag}_2.fq.gz")  into readPairs

        shell:
	file_tag = infile.baseName
		
        '''
        set -o pipefail
        samtools collate -uOn 128 !{file_tag}.bam tmp_!{file_tag} | samtools fastq -1 !{file_tag}_1.fq -2 !{file_tag}_2.fq -
	gzip !{file_tag}_1.fq
	gzip !{file_tag}_2.fq
        '''
    }
}else{
if(mode=='fastq'){
    println "fastq mode"
    
    keys1 = file(params.input_folder).listFiles().findAll { it.name ==~ /.*${params.suffix1}.${params.fastq_ext}/ }.collect { it.getName() }
                                                                                                               .collect { it.replace("${params.suffix1}.${params.fastq_ext}",'') }
    keys2 = file(params.input_folder).listFiles().findAll { it.name ==~ /.*${params.suffix2}.${params.fastq_ext}/ }.collect { it.getName() }
                                                                                                               .collect { it.replace("${params.suffix2}.${params.fastq_ext}",'') }
    if ( !(keys1.containsAll(keys2)) || !(keys2.containsAll(keys1)) ) {println "\n ERROR : There is not at least one fastq without its mate, please check your fastq files."; System.exit(0)}
    println keys1

// Gather files ending with _1 suffix
   reads1 = Channel
    .fromPath( params.input_folder+'/*'+params.suffix1+'.'+params.fastq_ext )
    .map {  path -> [ path.name.replace("${params.suffix1}.${params.fastq_ext}",""), path ] }

// Gather files ending with _2 suffix
   reads2 = Channel
    .fromPath( params.input_folder+'/*'+params.suffix2+'.'+params.fastq_ext )
    .map {  path -> [ path.name.replace("${params.suffix2}.${params.fastq_ext}",""), path ] }

// Match the pairs on two channels having the same 'key' (name) and emit a new pair containing the expected files
   readPairs = reads1
    .phase(reads2)
    .map { pair1, pair2 -> [ pair1[1], pair2[1] ] }

    println reads1
}
}

// pre-trimming QC
process fastqc_pretrim {
	cpus params.cpu
        memory params.mem_QC+'GB'    
        tag { file_tag }
        
        input:
        file pairs from readPairs
	
        output:
	file("${file_tag}${params.suffix1}_pretrim_fastqc.zip") into fastqc_pair1
	file("${file_tag}${params.suffix2}_pretrim_fastqc.zip") into fastqc_pair2
	file pairs into readPairs3
	val(file_tag) into filetag2
	publishDir params.output_folder, mode: 'copy', pattern: '{*fastqc.zip}'
	
	shell:
        file_tag = pairs[0].name.replace("${params.suffix1}.${params.fastq_ext}","")
        '''
	fastqc -t !{task.cpus} !{pairs[0]} !{pairs[1]}
	mv !{file_tag}!{params.suffix1}_fastqc.zip !{file_tag}!{params.suffix1}_pretrim_fastqc.zip
	mv !{file_tag}!{params.suffix2}_fastqc.zip !{file_tag}!{params.suffix2}_pretrim_fastqc.zip 
        '''
}

// adapter sequence trimming and post trimming QC
process adapter_trimming {
            cpus '1'
            memory params.mem_QC+'GB'
            tag { file_tag }
	    
            input:
	    val(file_tag) from filetag2
	    file pairs3 from readPairs3
            output:
            val(file_tag) into filetag3
	    file("${file_tag}*val*.fq.gz") into readPairs4
	    file("${file_tag}${params.suffix1}_val_1_fastqc.zip") into fastqc_postpair1
	    file("${file_tag}${params.suffix2}_val_2_fastqc.zip") into fastqc_postpair2
	    file("${file_tag}*trimming_report.txt") into trimming_reports
	    
	    publishDir params.output_folder, mode: 'copy', pattern: '{*report.txt,*fastqc.zip}'
	    
            shell:
            '''
	    trim_galore --paired --fastqc !{pairs3[0]} !{pairs3[1]}
            '''
}


//Mapping, mark duplicates and sorting
process alignment {
      cpus params.cpu
      memory params.mem+'G'
      tag { file_tag }
      
      input:
      val(file_tag) from filetag3
      file pairs5  from readPairs4
      file ref from ref.collect()
      file annot_gtf
                  
      output:
      val(file_tag) into filetag5
      file("${file_tag}.bam") into bam_files
      file("${file_tag}.bam.bai") into bai_files
      file("*.Log.final.out") into align_out
      if( (params.sjtrim == null)&(params.recalibration == null) ){
        publishDir params.output_folder, mode: 'copy'
      }else{
	publishDir params.output_folder, mode: 'copy', pattern: "Log.final.out"
      }
            
      shell:
      align_threads = params.cpu.intdiv(2)
      sort_threads = params.cpu.intdiv(2) - 1
      sort_mem     = params.mem.intdiv(4)
      
      if(params.hisat2){
            '''
            hisat2 --rg-id !{file_tag} --rg SM:!{file_tag} --rg !{params.RG} --met-file hisat2.!{file_tag}.Log.final.out -p !{align_threads} -x !{params.hisat2_idx} -1 !{pairs5[0]} -2 !{pairs5[1]} | samblaster --addMateTags | sambamba view -S -f bam -l 0 /dev/stdin | sambamba sort -t !{sort_threads} -m !{sort_mem}G --tmpdir=!{file_tag}_tmp -o !{file_tag}.bam /dev/stdin
	    '''
      }else{
      '''
      STAR --outSAMattrRGline ID:!{file_tag} SM:!{file_tag} !{params.RG} --chimSegmentMin 12 --chimJunctionOverhangMin 12 --chimSegmentReadGapMax 3 --alignSJDBoverhangMin 10 --alignMatesGapMax 200000 --alignIntronMax 200000 --alignSJstitchMismatchNmax 5 -1 5 5 --twopassMode Basic --runThreadN !{align_threads} --genomeDir . --sjdbGTFfile !{annot_gtf} --readFilesCommand zcat --readFilesIn !{pairs5[0]} !{pairs5[1]} --outStd SAM | samblaster --addMateTags | sambamba view -S -f bam -l 0 /dev/stdin | sambamba sort -t !{sort_threads} -m !{sort_mem}G --tmpdir=!{file_tag}_tmp -o !{file_tag}.bam /dev/stdin
      mv Log.final.out STAR.!{file_tag}.Log.final.out
      '''
      }
}

//Splice junctions trimming
if(params.sjtrim){
   process splice_junct_trim {
      cpus params.cpu
      memory params.mem+'G'
      tag { file_tag }
      
      input:
      val(file_tag) from filetag5
      file bam  from bam_files
      file bai  from bai_files
            
      output:
      val("${file_tag}_split") into filetag6
      file("${file_tag}_split.bam") into bam_files2
      file("${file_tag}_split.bam.bai") into bai_files2
      if(params.recalibration == null){
        publishDir params.output_folder, mode: 'copy'
      }
            
      shell:
      '''
      java -Xmx!{params.mem}g -Djava.io.tmpdir=. -jar !{params.GATK_folder}/GenomeAnalysisTK.jar -T SplitNCigarReads -R !{params.ref} -I !{bam} -o !{file_tag}_split.bam -rf ReassignOneMappingQuality -RMQF 255 -RMQT 60 -U ALLOW_N_CIGAR_READS
      mv !{file_tag}_split.bai !{file_tag}_split.bam.bai
      '''
   }
}else{
      filetag6=filetag5
      bam_files2=bam_files
      bai_files2=bai_files
}


//BQSrecalibration
if(params.recalibration){
   process base_quality_score_recalibration {
    	cpus params.cpu
	memory params.mem+'G'
    	tag { file_tag }
        
    	input:
    	val(file_tag) from filetag6
	file bam from bam_files2
    	file bai from bai_files2
    	output:
	val(file_tag) into filetag7
    	file("${file_tag}_recal.table") into recal_table_files
    	file("${file_tag}_post_recal.table") into recal_table_post_files
    	file("${file_tag}_recalibration_plots.pdf") into recal_plots_files
    	file("${file_tag}.bam") into recal_bam_files
    	file("${file_tag}.bam.bai") into recal_bai_files
    	publishDir params.output_folder, mode: 'move'

    	shell:
    	'''
    	indelsvcf=(`ls !{params.GATK_bundle}/*indels*.vcf* | grep -v ".tbi" | grep -v ".idx"`)
    	dbsnpvcfs=(`ls !{params.GATK_bundle}/*dbsnp*.vcf* | grep -v ".tbi" | grep -v ".idx"`)
    	dbsnpvcf=${dbsnpvcfs[@]:(-1)}
    	knownSitescom=''
    	for ll in $indelsvcf; do knownSitescom=$knownSitescom' -knownSites '$ll; done
    	knownSitescom=$knownSitescom' -knownSites '$dbsnpvcf
    	java -Xmx!{params.mem}g -Djava.io.tmpdir=. -jar !{params.GATK_folder}/GenomeAnalysisTK.jar -T BaseRecalibrator -nct !{params.cpu} -R !{params.ref} -I !{file_tag}.bam $knownSitescom -L !{params.bed} -o !{file_tag}_recal.table
    	java -Xmx!{params.mem}g -Djava.io.tmpdir=. -jar !{params.GATK_folder}/GenomeAnalysisTK.jar -T BaseRecalibrator -nct !{params.cpu} -R !{params.ref} -I !{file_tag}.bam $knownSitescom -BQSR !{file_tag}_recal.table -L !{params.bed} -o !{file_tag}_post_recal.table		
    	java -Xmx!{params.mem}g -Djava.io.tmpdir=. -jar !{params.GATK_folder}/GenomeAnalysisTK.jar -T AnalyzeCovariates -R !{params.ref} -before !{file_tag}_recal.table -after !{file_tag}_post_recal.table -plots !{file_tag}_recalibration_plots.pdf	
    	java -Xmx!{params.mem}g -Djava.io.tmpdir=. -jar !{params.GATK_folder}/GenomeAnalysisTK.jar -T PrintReads -nct !{params.cpu} -R !{params.ref} -I !{file_tag}.bam -BQSR !{file_tag}_recal.table -L !{params.bed} -o !{file_tag}.bam
    	mv !{file_tag}.bai !{file_tag}.bam.bai
    	'''
   }
}else{      
      filetag7=filetag6
      recal_bam_files=bam_files2
      recal_bai_files=bai_files2
}

recal_bam_files.into { recal_bam_files4QC; recal_bam_files4quant }
recal_bai_files.into { recal_bai_files4QC; recal_bai_files4quant }
filetag7.into{ filetag7A; filetag7B }

//RSEQC
process RSEQC{
    	cpus '1'
	memory params.mem_QC+'GB'
    	tag { file_tag }
        
    	input:
    	val(file_tag) from filetag7A
	file bam from recal_bam_files4QC
    	file bai from recal_bai_files4QC
    	output:
	file("${file_tag}_readdist.txt") into rseqc_files
    	publishDir params.output_folder, mode: 'copy'

    	shell:
    	'''
	read_distribution.py -i !{file_tag}".bam" -r !{params.bed} > !{file_tag}"_readdist.txt"
    	'''
}

//Quantification
process quantification{
    	cpus '1'
	memory params.mem_QC+'GB'
    	tag { file_tag }
        
    	input:
    	val(file_tag) from filetag7B
	file bam from recal_bam_files4quant
    	file bai from recal_bai_files4quant
	file annot_gtf

    	output:
	file("${file_tag}_count.txt") into htseq_files
    	publishDir params.output_folder, mode: 'copy'

    	shell:
	buffer=''
	if(params.htseq_maxreads) buffer='--max-reads-in-buffer '+params.htseq_maxreads+' '+'--additional-attr gene_name'
	//check later if htseq 0.8 options --nonunique and --additional-attr are useful
    	'''
	htseq-count -r !{params.order} -s !{params.stranded} -f bam !{file_tag}.bam !{annot_gtf} !{buffer} > !{file_tag}_count.txt 
    	'''
}

//Transcript discovery 
//stringtie !{file_tag}.bam -o !{file_tag}.gtf -p !{cpus} -G !{annot_gtf} -l !{file_tag} -C !{file_tag}_cov_refs.gtf
//ls *.gtf > mergelist.txt
//stringtie --merge -p !{cpus} -G !{annot_gtf} -o stringtie_merged.gtf mergelist.txt
//gffcompare -r !{annot_gtf} -G -o !{file_tag} !{file_tag}.gtf
//stringtie -e -B -p !{cpus} -G stringtie_merged.gtf -o !{file_tag}_merged.gtf !{file_tag}.bam -A !{file_tag}_gene_abund.tab -B


process multiqc_pretrim {
    cpus '1'
    memory params.mem_QC+'GB'
    tag { "all"}
        
    input:
    file fastqc1 from fastqc_pair1.collect()
    file fastqc2 from fastqc_pair2.collect()
        
    output:
    file("multiqc_pretrim_report.html") into multiqc_pre
    file("multiqc_pretrim_report_data") into multiqc_pre_data
    publishDir params.output_folder, mode: 'copy'

    shell:
    '''
    for f in $(find *fastqc.zip -type l);do cp --remove-destination $(readlink $f) $f;done;
    multiqc . -n multiqc_pretrim_report.html -m fastqc
    '''
}


if(params.clustering) htseq_files.into { htseq_files ; htseq_files4clust }


process multiqc_posttrim {
    cpus '1'
    memory params.mem_QC+'GB'
    tag { "all"}
        
    input:
    file fastqcpost1 from fastqc_postpair1.collect()
    file fastqcpost2 from fastqc_postpair2.collect()
    file STAR from align_out.collect()
    file htseq from htseq_files.collect()
    file rseqc from rseqc_files.collect()
    file trim from trimming_reports.collect()
        
    output:
    file("multiqc_posttrim_report.html") into multiqc_post
    file("multiqc_posttrim_report_data") into multiqc_post_data

    publishDir params.output_folder, mode: 'copy'

    shell:
    '''
    for f in $(find *fastqc.zip -type l);do cp --remove-destination $(readlink $f) $f;done;
    multiqc . -n multiqc_posttrim_report.html -m fastqc -m cutadapt -m star -m rseqc -m htseq
    '''
}

if(params.clustering){
   process clustering {
    	cpus params.cpu
	memory params.mem_QC+'G'
    	tag { "all" }
        
    	input:
	file htseq from htseq_files4clust.collect()
	output:
    	file("unsupervised_analysis") into unsup_res
    	publishDir params.output_folder, mode: 'move'

    	shell:
    	'''
	RNAseq_unsupervised.R -o unsupervised_analysis -n 500 -t vst -c hc -l complete
    	'''
   }
}