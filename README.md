# Sanger Blast Pipeline

**A localized, high-throughput BLAST annotation pipeline designed for Sanger sequencing data.**

English | [中文](https://www.google.com/search?q=./README_zh-CN.md)

## Background

In microbial isolation and identification, PCR amplification of the bacterial 16S rRNA gene using universal primers like 27F/1492R, followed by Sanger sequencing, is an economical, efficient, and widely-used method for species identification.

However, when dealing with a large number of sequencing samples, relying on the NCBI website or other web-based tools for sequence alignment (BLAST) becomes inefficient due to **network limitations** and **performance bottlenecks**. While a local BLAST setup is the ideal solution, its environment configuration and command-line operations present a technical barrier for beginners.

**This project aims to eliminate this barrier** by providing an automated, beginner-friendly pipeline that allows researchers to easily perform batch BLAST annotations for Sanger sequencing data on their local computers.

---

## Key Features

* **End-to-End Automation:** Automatically handles sequence linearization, dynamic trimming, high-throughput BLAST alignment, and top-hit result summarization.
* **Smart Database Management:** Supports both **Online Auto-Update** (via wget/curl) and **Offline Manual Update**. Automatically tracks version dates, verifies MD5 checksums, and safely archives older databases.
* **Dynamic Sequence Trimming:** Built-in support to specify bases to trim from the left and the exact length to keep, ensuring high-quality alignment regions.
* **High-Throughput Acceleration:** Utilizes GNU Parallel to process numerous sequence files concurrently, making full use of multi-core CPU performance.
* **Robust Logging & Tracking:** Dynamically generates detailed execution logs and database version info (`db_version_info.txt`) in the output directory for maximum reproducibility.
* **Easy & Strict Configuration:** Centralized config file with strict path validation for dependencies, preventing runtime errors.

---

## Quick Start

### 1. Clone the Project

Clone the project to your local machine using one of the following methods:

```bash
# Method 1: Clone from GitHub
git clone https://github.com/CTR42/sanger_blast.git

# Method 2: For users in China, cloning from Gitee may be faster
git clone https://gitee.com/CTR42/sanger_blast.git

# Enter the project directory
cd sanger_blast

```

### 2. Install Dependencies

This pipeline relies on **NCBI BLAST+** and **GNU Parallel**.

* **NCBI BLAST+**: [Official Download and Installation Guide](https://www.ncbi.nlm.nih.gov/books/NBK279671/)
* **GNU Parallel**: On Debian/Ubuntu: `sudo apt-get install parallel` | On macOS: `brew install parallel`

### 3. Initial Setup

A one-time setup is required before the first use.

**a. Grant Execute Permissions**

```bash
# Add execute permissions to all .sh scripts in the project directory
find . -type f -name "*.sh" -exec chmod +x {} +

```

**b. Create and Modify the Configuration File**
Copy the configuration template to create your own config file:

```bash
cp sanger_blast.config.example sanger_blast.config

```

Open `sanger_blast.config` with a text editor (e.g., `vim` or `nano`) and configure the following absolute paths:

* `NCBI_16S_DB_DIR`: The directory where you want to store the BLAST databases.
* `BLASTN_PATH`: The absolute path to your `blastn` executable (e.g., `/usr/local/bin/blastn`).
* `PARALLEL_PATH`: The absolute path to your `parallel` executable (e.g., `/usr/bin/parallel`).

---

## Usage

The pipeline is operated via the main script `sanger_blast_pipeline.sh` and is divided into two main subcommands: **Database Update (`update`)** and **Annotation Pipeline (`-i`)**.

### Mode 1: Database Update (`update`)

Before running any annotations, you must set up the local NCBI 16S database.

**Online Auto-Update:**
If your server has a stable internet connection, simply run:

```bash
bash sanger_blast_pipeline.sh update

```

*The script will automatically fetch the latest 16S database, verify the MD5, extract it, and archive any previous versions.*

**Offline Manual Update:**
If your server is in an offline environment or facing network restrictions, you can download the `.tar.gz` and `.md5` files manually on your local computer, transfer them to the server, and run:

```bash
bash sanger_blast_pipeline.sh update -f /path/to/16S_ribosomal_RNA.tar.gz -m /path/to/16S_ribosomal_RNA.tar.gz.md5

```

*The script will securely deploy the local files without attempting network requests.*

### Mode 2: Annotation Pipeline

Run the batch annotation using your sequencing data.

**Command Syntax:**

```bash
bash sanger_blast_pipeline.sh -i <input_folder> [options]

```

**Arguments:**

| Argument | Description | Default Value |
| --- | --- | --- |
| **`-i <folder>`** | **(Required)** The input folder containing raw sequence files. | None |
| `-o <folder>` | The output directory for results and logs. | `./blast_out` |
| `-t <string>` | Sequence type: `single-end` (triggers trimming) or `contig`. | `single-end` |
| `-x <string>` | The file extension of sequence files (without the dot). | `seq` |
| `-n <integer>` | Number of parallel threads to use. | `8` |
| `-l <integer>` | Number of bases to trim from the **left** (5' end). | `30` |
| `-k <integer>` | The total sequence length to **keep** after left trimming. | `700` |
| `-d <path>` | Specific local database path (if bypassing the config). | Config's `latest` |
| `-h` | Show help message. | N/A |

**Usage Examples:**

*Example 1: Basic alignment with customized threads*

```bash
bash sanger_blast_pipeline.sh -i data/raw_reads -o output/results -n 16 -x fasta

```

*Example 2: Customized sequence trimming*
Trim 50 bases from the left to remove low-quality primer regions, and keep exactly 800 bases:

```bash
bash sanger_blast_pipeline.sh -i data/raw_reads -o output/results -l 50 -k 800

```

---

## Output Structure

Upon successful completion, your specified output directory (e.g., `blast_out/`) will contain:

1. **`summary.txt`**: The final aggregated report containing the top-hit species, Accession numbers, Max Score, E-value, and Identify percentage for every input sequence.
2. **Individual Result Files (`*_blast_out.txt`)**: Detailed BLAST alignments for each specific sequence.
3. **`sanger_blast_YYYYMMDD_HHMMSS.log`**: A complete execution log of the run, dynamically moved to the output folder for archiving.
4. **`db_version_info.txt`** *(Appended to the log)*: A record verifying the exact NCBI database version and timestamp used for this specific analysis.