library(adegenet)
sceloporus_data <- read.genepop("~/Downloads/doi_10.5061_dryad.sxksn0316__v2/microsatellite_genotypes.gen",
                                ncode = 3,
                                quiet = F)
sceloporus_data_df <- genind2df(sceloporus_data)
sceloporus_data_df[apply(sceloporus_data_df, 2, is.na)] <- "000000"
sceloporus_data_df

sceloporus_data_df[1,2]


paste(substr(sceloporus_data_df[1,2], 1, 3),
      substr(sceloporus_data_df[1,2], 4, 6),
      sep = "/")


sceloporus_data_mt <- apply(sceloporus_data_df[,-1], 2, function(x){
  paste(substr(x, 1, 3), substr(x, 4, 6), sep = "/")
})
sceloporus_data_mt <- cbind(as.character(sceloporus_data_df[,1]), sceloporus_data_mt)
rownames(sceloporus_data_mt) <- rownames(sceloporus_data_df)
sceloporus_data_mt

split(sceloporus_data_mt[, -1], sceloporus_data_df[,1])
