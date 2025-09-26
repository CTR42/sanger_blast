# Sanger Blast Pipeline

**A localized, high-throughput BLAST annotation pipeline designed for Sanger sequencing data.**

English | [中文](./README_zh-CN.md)

## Background

In microbial isolation and identification, PCR amplification of the bacterial 16S rRNA gene using universal primers like 27F/1492R, followed by Sanger sequencing, is an economical, efficient, and widely-used method for species identification.

However, when dealing with a large number of sequencing samples, relying on the NCBI website or other web-based tools for sequence alignment (BLAST) becomes inefficient due to **network limitations** and **performance bottlenecks**. While a local BLAST setup is the ideal solution, its environment configuration and command-line operations present a technical barrier for beginners.

**This project aims to eliminate this barrier** by providing an automated, beginner-friendly pipeline that allows researchers to easily perform batch BLAST annotations for Sanger sequencing data on their local computers.

## Key Features

  * **Automation**: Automatically downloads and updates the NCBI 16S rRNA database.
  * **High-Throughput**: Utilizes GNU Parallel to process numerous sequence files concurrently, making full use of multi-core CPU performance.
  * **Easy Configuration**: Requires modifying only a single configuration file to specify tool and database paths.
  * **Flexible and User-Friendly**: Supports custom parameters for input/output directories, number of threads, file extensions, and more.
  * **Cross-Platform**: Runs on any system with a Bash environment (Linux, macOS, WSL on Windows).

## Quick Start

### 1\. Clone the Project

Clone the project to your local machine using one of the following methods:

```bash
# Method 1: Clone from GitHub
git clone https://github.com/CTR42/sanger_blast.git

# Method 2: For users in China, cloning from Gitee may be faster
git clone https://gitee.com/CTR42/sanger_blast.git

# Enter the project directory
cd sanger_blast
```

### 2\. Install Dependencies

This pipeline relies on `NCBI BLAST+` and `GNU Parallel`.

  * **NCBI BLAST+**: Used to perform local sequence alignments.
      * [Official Download and Installation Guide](https://www.ncbi.nlm.nih.gov/books/NBK279671/)
  * **GNU Parallel**: Used to process tasks in parallel, speeding up the pipeline.
      * [Official Website](https://www.gnu.org/software/parallel/)
      * On Debian/Ubuntu-based systems: `sudo apt-get update && sudo apt-get install parallel`
      * On macOS with Homebrew: `brew install parallel`

### 3\. Initial Setup

A one-time setup is required before the first use.

**a. Grant Execute Permissions**

```bash
# Add execute permissions to all .sh scripts in the project directory
find . -type f -name "*.sh" -exec chmod +x {} +
```

**b. Create and Modify the Configuration File**

A configuration template is provided. To avoid conflicts with future updates, please create a copy before editing.

```bash
# Copy the configuration template
cp sanger_blast.config.example sanger_blast.config
```

Next, open the `sanger_blast.config` file with your favorite text editor (e.g., `vim` or `nano`).

```bash
# Edit with vim (recommended)
vim sanger_blast.config

# Or edit with nano (more beginner-friendly)
# nano sanger_blast.config
```

You will need to modify two path variables in this file:

  * `BLAST_PLUS_DIR`: The path to the `bin` directory of your `NCBI BLAST+` installation (e.g., `/home/user/miniconda3/bin`).
  * `NCBI_16S_DB_DIR`: A directory where you want to store the BLAST databases (e.g., `/path/to/your/blast_db`).

*Simple Vim Tip: Press `i` to enter insert mode. After making your changes, press `Esc` to exit insert mode, then type `:wq` and press Enter to save and quit.*

## Usage

Once configured, you can run the annotation pipeline using the `sanger_blast_pipeline.sh` script.

### Argument Descriptions

```bash
sanger_blast_pipeline.sh -i <input_folder> -d <blast_db> -o <output_folder> -m <sequence_type> -n <threads> -x <file_extension> [-h]
```

| Argument | Description |
| :--- | :--- |
| **`-i <folder_path>`** | **(Required)** The input folder containing your Sanger sequencing files. |
| `-o <folder_path>` | The output directory. (Default: `./blast_out`) |
| `-d <db_path>` | Specifies the path to a local BLAST database. (Default: Uses the latest specified in the config file) |
| `-m <seq_type>` | The sequence type: `single-end` or `contig`. (Default: `single-end`) |
| `-n <integer>` | The number of parallel jobs/threads to run. (Default: `8`) |
| `-x <extension>` | The file extension of sequence files, without the ".". (Default: `seq`) |
| `-u <boolean>` | Whether to update the database: `true` or `false`. (Default: `false`) |
| `-h` | Shows this help message. |

### Usage Examples

**Example 1: Basic Usage**

Assume your sequencing files (with a `.fasta` extension) are located in the `data/raw_reads` directory, and you want to perform the alignment using 16 threads, saving the results to the `output/blast_results` folder.

```bash
bash sanger_blast_pipeline.sh -i data/raw_reads -o output/blast_results -n 16 -x fasta
```

**Example 2: First Run or Updating the Database**

If this is your first time running the pipeline, or if you wish to automatically check for and update the NCBI 16S database before running, set the `-u` flag to `true`.

```bash
bash sanger_blast_pipeline.sh -i data/raw_reads -u true
```

*The pipeline will automatically handle the database download, extraction, and naming processes for you.*

## Output

After the pipeline finishes, you will find result files named after your input files (e.g., `sample1.txt`) in the specified output directory (default: `blast_out`). Each result file contains the best-matching species information from the NCBI 16S database for the corresponding sequence. A summary file named `summary.txt` will also be generated.