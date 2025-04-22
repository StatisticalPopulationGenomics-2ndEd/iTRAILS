library(tidyverse)

hidden_states <- read_csv("./data/output/viterbi/hidden_states.csv")
post_block32 <- read_csv("./data/output/posterior/exampleblck32.posterior.csv")
viterbi <- read_csv("./data/output/viterbi/exampleblck32.viterbi.csv")

state_mapping <- hidden_states %>% 
  select(state_idx, topology)

post_long <- post_block32 %>%
  pivot_longer(
    cols = -c(alignment_block_idx, position_idx),
    names_to = "topology",
    values_to = "probability"
    ) %>% 
  select(-alignment_block_idx)  %>%
  mutate(
    topology = str_replace_all(topology, "sp1", "Human"),
    topology = str_replace_all(topology, "sp2", "Chimp"),
    topology = str_replace_all(topology, "sp3", "Gorilla")
  )


viterbi <- viterbi %>%
  mutate(most_likely_state = as.numeric(most_likely_state)) %>%
  left_join(state_mapping, by = c("most_likely_state" = "state_idx")) %>%
  arrange(position_start) %>% 
  select(-Block_idx) %>% 
  select(-most_likely_state)  %>%
  mutate(
    topology = str_replace_all(topology, "sp1", "Human"),
    topology = str_replace_all(topology, "sp2", "Chimp"),
    topology = str_replace_all(topology, "sp3", "Gorilla")
  )


max_top <- post_long %>%
  group_by(position_idx) %>%
  slice_max(probability, n = 1, with_ties = TRUE) %>% 
  slice(1) %>%  
  ungroup() %>%
  arrange(position_idx)

max_post <- max_top %>%
  arrange(position_idx) %>%
  mutate(group = cumsum(topology != lag(topology, default = first(topology)))) %>%
  group_by(group, topology) %>%
  summarize(
    position_start = first(position_idx),
    position_end   = last(position_idx),
    .groups = "drop"
  ) %>%
  select(-group) %>%
  mutate(
    topology = str_replace_all(topology, "sp1", "Human"),
    topology = str_replace_all(topology, "sp2", "Chimp"),
    topology = str_replace_all(topology, "sp3", "Gorilla")
  )


padding <- 0.025

top_vec <- c("({Human,Chimp},Gorilla)", 
             "((Human,Chimp),Gorilla)", 
             "((Human,Gorilla),Chimp)", 
             "((Chimp,Gorilla),Human)")
             
p <- ggplot(post_long) +
  geom_line(aes(x = position_idx, y = probability, color = topology)) +
  geom_rect(aes(xmin = position_start, xmax = position_end, 
              ymin = 1.11 - padding, ymax = 1.11 + padding, 
              fill = topology, color = topology),
          data = viterbi) +
  geom_rect(aes(xmin = position_start, xmax = position_end, 
              ymin = 1.05 - padding, ymax = 1.05 + padding, 
              fill = topology, color = topology),
          data = max_post) +
  scale_color_brewer(palette = "Set1", 
                    breaks = top_vec, 
                    labels = top_vec) +
  scale_fill_brewer(palette = "Set1", 
                    breaks = top_vec, 
                    labels = top_vec) +
  scale_y_continuous(breaks = c(0, 0.25, 0.5, 0.75, 1, 1.05, 1.11), 
                     labels = c(0, 0.25, 0.5, 0.75, 1, "MaxP", "Viterbi")) +
  scale_x_continuous(expand = c(0, 0)) +
  theme_bw() +
  theme(panel.grid = element_blank(),
        panel.border = element_rect(color = "black", fill = NA)) +
  geom_hline(yintercept = c(0, 0.25, 0.5, 0.75, 1), 
             color = "grey80", linetype = "dashed") +
  labs(x = "Position (bp)", y = "Posterior probability", 
       fill = "Genealogy", color = "Genealogy")


ggsave(filename = "./plot.png", 
       plot = p, width = 12, height = 6, dpi = 600)