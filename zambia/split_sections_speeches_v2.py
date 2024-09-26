#Packages
import re
import pandas as pd
from tqdm import tqdm
import datetime
from datetime import date as d


#import csv
path = "/Users/jacobwinter/Dropbox/parl_debates_data/zambia_data/"
file = "parl_debates_zm_2024_01_22.csv"
corpus = pd.read_csv(path+file) #All agreement types


#corpus['text'][0]
#choose a random set
#corpus = corpus.sample(10)

rownum = corpus.index[corpus['url'] == 'https://www.parliament.gov.zm/node/537'].tolist()
corpus['text'][rownum] = corpus['text'][rownum].str.replace("Appendix.*", "", regex=True)

corpus = corpus[corpus['text'] != "ERROR"]
#corpus = corpus[corpus['url'] == "https://www.parliament.gov.zm/node/534"]
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
        text = re.sub("{mospagebreak}","", text) #get rid of this artefact as it can mess up identifying headers
        sections = re.split('(\n[\'\’,.!/A-Z0-9 ]{3,}\n)', text)
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
        for i in range(1, len(sections), 2):
          sec = "\n"+sections[i+1]

          names = re.split('(\n.{0,200}:)', sec)
          #print(i)
          #print(names[0])
          header = (sections[i])
      
          if len(names)>1:
            for ii in range(1, len(names), 2):
                speakers.append(names[ii])
                texts.append(names[ii+1])
                dates.append(date)
                urls.append(url)
                section_name.append(header)
  

df = pd.DataFrame(
    {'date': dates, 'section_name':section_name, 'speaker': speakers, 'text':texts, 'url':urls}
)    
today = d.today()
d1 = today.strftime("%Y_%m_%d")

df.to_csv(path + "split_debates_sec_" + d1 + ".csv")
print(path + "split_debates_sec_" + d1 + ".csv")

