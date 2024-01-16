#Packages
import re
import pandas as pd
from tqdm import tqdm
import datetime

#import csv
path = "/Users/jacobwinter/Dropbox/parl_debates_data/zambia_data/"
file = "parl_debates_zm_2023_07_20.csv"
corpus = pd.read_csv(path+file) #All agreement types


corpus['text'][0]
#choose a random set
#corpus = corpus.sample(100)

#corpus['year'] = corpus['date'].astype(str).str[-4:]
#is_2010 = corpus['year']=='2010'
#corpus = corpus[is_2010]

speakers = []
texts = []
dates = []
section_list = []
section_name = []
urls = []
rownum = 0


for index, row in tqdm(corpus.iterrows(), total=corpus.shape[0]):
    #text = corpus.iloc[i, 2]
    text= row['text']
    if isinstance(text, str):
        sections = re.split('-----|_____', text)
        date = row['date']
        date = re.sub("Monday, |Tuesday, |Wednesday, |Thursday, |Friday, |Saturday, |Sunday, |Debates-|st|th|nd|rd", "", date)
        date = re.sub("Otober", "October", date)
        date = re.sub("Augu", "August", date)
        day = re.findall('[0-3][0-9]|[0-9]', date)[0]
        month = re.findall('January|February|March|April|May|June|July|August|September|October|November|December', date)[0]
        month = datetime.datetime.strptime(month, "%B")
        month = month.month
        year = re.findall('[0-9]{4}', date)[0]
        date = str(year)+"-"+str(month)+"-"+str(day)
        url = row['url']
        #date = datetime.datetime.strptime(re.sub(r"\b([0123]?[0-9])(st|th|nd|rd)\b",r"\1", date), "%d %B, %Y")
        i = 1
        s = 0
        for sec in sections:
          
            names = re.split('(\n.{0,100}:)', sec)
            #print(names[0])
            s = s+1
            for slice in names[1:]: #Skip the first (intro) line, go every other between speaker and text
                if (i % 2) == 0:
                    #slice = re.sub("\n", " ", slice)
                    texts.append(slice)
                else:
                    #slice = re.sub("\n", "", slice)
                    speakers.append(slice)
                    dates.append(date)
                    urls.append(url)
                    section_list.append(s)
                    section_name.append(names[0])
                i = i+1
                

len(texts)
len(speakers)
len(urls)


df = pd.DataFrame(
    {'date': dates, 'section_num': section_list, 'section_name':section_name, 'speaker': speakers, 'text':texts, 'url':urls}
)


df.to_csv(path+"/split_debates_sec.csv")
