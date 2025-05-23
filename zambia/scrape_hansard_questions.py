from tqdm import tqdm
import re
import pandas as pd
from datetime import datetime, date as d

path = "/Users/jacobwinter/Dropbox/parl_debates_data/zambia_data/"
file = "parl_debates_zm_2024_01_22.csv"
corpus = pd.read_csv(path+file) #All agreement types

def extract_vars(question, speakers):
    try:
        number = re.findall('([Ww0-9\.]+ )', question)[0]
        number = re.sub("\n","", number)
    except:
        number = "ERROR"

    try:
        constit = re.findall('\([A-z\s]+\)',question)[0]
        constit = re.sub("\(|\)","", constit.lower())
    except:
        constit = "ERROR"

    try:
        speaker = re.findall('([A-Za-z\.]+)\s([A-Za-z]+)\s\(([^)]+)\)', question)
        speaker = speaker[0][1]
    except:
        try:#Get third word
            speaker = re.findall('[A-z]* asked', question)
            speaker = re.sub(" asked","", speaker[0])
            speaker


            constit = next((item for item in speakers if speaker in item), None)
            constit = re.sub(speaker,"", constit)
            constit = re.sub("\(|\)","", constit.lower())
        except:
            speaker = "ERROR"

    try:
        adressees = re.findall('ask.*?(?=how|when|why|what|whether|who|[.:!?\(\n])', question)[0]
    except:
        adressees = "ERROR"

    try:
        text = re.split(adressees, question)[1]
        text = re.sub("\n", " ", text)
        text = re.sub("  ", " ", text)
    except:
        text = "ERROR"

    return [number, constit, speaker, adressees, text]

def extract_date(date):
    date = re.sub("Monday, |Tuesday, |Wednesday, |Thursday, |Friday, |Saturday, |Sunday, |Debates-|st|th|nd|rd", "", date)
    date = re.sub("Otober", "October", date)
    date = re.sub("Augu", "August", date)
    day = re.findall('[0-3][0-9]|[0-9]', date)[0]
    day = int(day)
    day = str(day)
    if int(day) < 10:     #pad with zero if int(day) < 10
        day = "0" + day
    month = re.findall('January|February|March|April|May|June|July|August|September|October|November|December', date)[0]
    month = datetime.strptime(month, "%B")
    month = month.month
    year = re.findall('[0-9]{4}', date)[0]
    date = str(year)+"-"+str(month)+"-"+str(day)
    date = datetime.strptime(date, "%Y-%m-%d")
    return date

questioners = []
constits = []
question_numbers = []
adressees = []
texts = []
dates = []
urls = []
full= []

#corpus = corpus[corpus['url']=="https://www.parliament.gov.zm/node/8936"]
corpus = corpus[corpus['text'] != "ERROR"]


pattern = "[0-9]+[A-z \.\(\)]*(Minister|minister).+:"
for index, row in tqdm(corpus.iterrows(), total=corpus.shape[0]):
    text= row['text']
    text = re.sub("’","", text) #Fix some typing errors manually
    text = re.sub("to the Minister", "to ask the Minister", text)
    text = re.sub("the.Minister", "the Minister", text) 
    text = re.sub("BGMET (METFORMIN)", "bgmet (metformin)", text)
    text = re.sub("Itezhi-Tezhi", "Itezhi Tezhi", text)
    if isinstance(text, str):
        text = re.sub("{mospagebreak}","", text) #get rid of this artefact as it can mess up identifying headers
        sections = re.split('(\n[\'\’,.!/A-Z0-9 ]{3,}\n)', text)

        date = extract_date(row['date'])

        speakers = re.findall('[A-Z]{1}[a-z]+ \([A-z ]+\)', text)
        lines = re.split('(\n)', text)
        for line in lines:
            match = re.search(pattern, line)
            if match:
                vars = extract_vars(line, speakers)
                question_numbers.append(vars[0])
                constits.append(vars[1])
                questioners.append(vars[2])
                adressees.append(vars[3])
                texts.append(vars[4])
                dates.append(date)
                urls.append(row['url'])
                full.append(line)
                

df = pd.DataFrame(
    {'date': dates, 'question_number': question_numbers, 'constit':constits, 'speaker': questioners, 'addressee': adressees,# 'text':texts,
     'full':full, 'url':urls}
)

df['written'] = [1 if "w" in x.lower() else 0 for x in df['question_number']]

df.to_csv(path+"questions_zm_from_hansard.csv", index=False)


