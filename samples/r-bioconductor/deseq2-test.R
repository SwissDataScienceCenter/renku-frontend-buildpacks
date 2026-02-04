library(DESeq2)

# Create tiny fake count data (3 genes, 4 samples)
countData <- matrix(
  c(100, 200, 50, 80,
    300, 350, 400, 420,
    1000, 1100, 900, 950),
  nrow = 3,
  byrow = TRUE,
  dimnames = list(
    c("gene1", "gene2", "gene3"),
    c("sample1", "sample2", "sample3", "sample4")
  )
)

# Sample metadata (2 conditions, 2 replicates each)
colData <- data.frame(
  condition = factor(c("control", "control", "treated", "treated")),
  row.names = colnames(countData)
)

# Create DESeqDataSet object
dds <- DESeqDataSetFromMatrix(
  countData = countData,
  colData = colData,
  design = ~ condition
)

# Run DESeq2 pipeline
dds <- DESeq(dds)

# Get results
res <- results(dds)

# Print results
print(res)

# Quick summary
summary(res)

# If you see output without errors, DESeq2 is working!
cat("\n✓ DESeq2 is working correctly!\n")
