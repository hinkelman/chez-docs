# Extract table from Summary of Forms page of Chez User's Guide

library(tidyverse)
library(rvest)

chez_url = "https://cisco.github.io/ChezScheme/csug9.5/summary.html"

chez_links <- read_html(chez_url) %>% 
  html_nodes("table") %>% 
  html_nodes("tr") %>% 
  html_nodes("a") %>% 
  html_attr("href")

chez_table_list <- read_html(chez_url) %>% 
  html_nodes("table") %>% 
  html_table()

chez_table <- chez_table_list[[1]] %>% 
  filter(Form != "") %>%          # drop empty first row
  mutate(URL = chez_links,
         # clean up extracted links to TSPL
         URL = gsub(pattern = "http://scheme.com/tspl4/./",
                    replacement = "https://scheme.com/tspl4/",
                    URL),
         # convert relative to absolute links for CSUG
         URL = gsub(pattern = "^\\.", 
                    replacement = "https://cisco.github.io/ChezScheme/csug9.5", 
                    x = URL),
         Key = sapply(strsplit(Form, "\\s"), "[[", 1),
         Key = gsub("\\(|\\)", "", Key),
         Source = ifelse(substr(Page, 1, 1) == "t", "TSPL", "CSUG")) %>% 
  select(Key, Form, Source, URL) 

source_list <- list()
excluded_list <- list()
for (j in c("CSUG", "TSPL")){
  ct_source <- filter(chez_table, Source == j)
  key_list <- list()
  excluded <- c()
  for (i in unique(ct_source$Key)){
    ctsk <- filter(ct_source, Key == i)
    if (nrow(ctsk) == 1){
      key_list[[i]] <- ctsk
    } else {
      if (nrow(unique(select(ctsk, Key, Source, URL))) == 1){
        key_list[[i]] <- tibble(Key = i,
                                Form = paste(unique(ctsk$Form), collapse = "~"),
                                Source = j,
                                URL = ctsk$URL[1])
      } else {
        excluded <- c(excluded, i)
      }
    }
  }
  excluded_list[[j]] <- excluded
  source_list[[j]] <- bind_rows(key_list)
}
out <- bind_rows(source_list)

for (j in c("CSUG", "TSPL")){
  out %>% 
    filter(Source == j) %>% 
    select(-Source) %>% 
    write_tsv(paste0(j, ".tsv"))
}

