daily_df <- split

daily_df$otherspeakers



match_member <- function(daily_df){
  
  output = data.frame()
  todays_speakers <- c()
  todays_assembly <- daily_df$assembly[1]
  
  
  member_pool <- constit_panel %>% 
    filter(assembly == todays_assembly)
  
  for(r in 1:nrow(daily_df)){ #Loop through that day's speeches
    source = daily_df[r,]
    
    if(str_length(source$otherspeakers)>1){ #Check if it is speaker/opposition, etc
      row <- data.frame(unique = paste0(source$otherspeakers,"_", source$session),
                        name = source$otherspeakers)
    }
    else{ #Otherwise, check if there is an easy single match, and make that the row
      matches <- member_pool %>% 
        mutate(match = str_extract(source$speaker_clean, surname),
               match_score = 10) %>% 
        filter(!is.na(match))
      row <- matches[1,]
      row$num_matches = nrow(matches)
      
      if(!nrow(matches)==1){ #If there is more than one match, then filter based on criteria
        matches <- member_pool %>% 
          mutate(match = str_extract(source$speaker_clean, surname),
                 match_val = ifelse(is.na(match),0,3), #Score 3 for surname match
                 
                 match_constit = str_extract(source$speaker_clean, district_for_matching),
                 match_constit_val = ifelse(is.na(match_constit),0,3),
                 
                 match_first = str_extract(source$speaker_clean, first_name),
                 match_first_val = ifelse(is.na(match_first),0,1),
                 
                 match_other = str_extract(source$speaker_clean, other_name),
                 match_other = ifelse(str_length(match_other)<2,NA,match_other), #Skip single letter matches
                 match_other_val = ifelse(is.na(match_other),0,1),
                 
                 match_init = str_extract(source$speaker_clean, init_name),
                 match_init_val = ifelse(is.na(match_init),0,1),
                 
                 match_prev_val = ifelse(unique %in% todays_speakers, 2, 0),
                 match_score = match_val+match_first_val+match_init_val+match_other_val+match_constit_val+match_prev_val #Score for max matches
          ) %>% 
          arrange(desc(match_score),
                  desc(str_length(match)))
      }
      if(max(matches$match_score>2)){row <- matches[1,]} #assign row if highest score is greater than 1
      else{row=data.frame(unique = NA, name ='unmatched')} #Otherwise show as missing
    }
    todays_speakers <- c(todays_speakers, row$unique[1])
    output <- plyr::rbind.fill(output, row)
  }
  
  return(output)
}


