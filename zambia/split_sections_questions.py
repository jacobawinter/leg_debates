
#Packages
import re
import pandas as pd
from tqdm import tqdm
import datetime    

def split_to_sections(text):
        text = re.sub("\xa0",u" ", text) #get rid of this artefact as it can mess up identifying headers
        text = re.sub("{mospagebreak}","", text) #get rid of this artefact as it can mess up identifying headers
        sections = re.split('([A-Z]{5,}[A-Z0-9 \.\,\-\:\)\(]{5,})', text)
        return sections

def split_to_questions(section):
    questions = re.split('(\\n[Ww0-9\.]+\s)', section) #Split by ID num and new line
    #Concat 1 and 2, 3 and 4 etc
    questions = [questions[i]+questions[i+1] for i in range(1, len(questions), 2)] #add number to text, skipping first line with header
    return questions

def extract_vars(question):
    try:
        number = re.findall('(\\n[Ww0-9\.]+ )', question)[0]
        number = re.sub("\n","", number)
    except:
        number = "ERROR"

    try:
        consit = re.findall('\([A-z\s]+\)',question)[0]
        consit = re.sub("\(|\)","", consit.lower())
    except:
        consit = "ERROR"

    try:
        speaker = re.findall('([A-Za-z\.]+)\s([A-Za-z]+)\s\(([^)]+)\)', question)
        speaker = speaker[0][1]
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

    return [number, consit, speaker, adressees, text]



#Start Code
if __name__ == "__main__":
    #import csv
    path = "/Users/jacobwinter/Dropbox/parl_debates_data/zambia_data/"
    file = "order_papers_zm_2024_07_25.csv"
    corpus = pd.read_csv(path+file) #

    corpus = corpus.drop_duplicates(subset=['date'], keep='first') #Keep only first value for each date



    speakers = []
    constits = []
    question_numbers = []
    adressees = []
    texts = []
    dates = []
    urls = []
    full= []

for index, row in tqdm(corpus.iterrows(), total=corpus.shape[0]):
    #text = corpus.iloc[699, 2]
    text= row['text']
    text = re.sub("’","", text) #Fix some typing errors manually
    text = re.sub("to the Minister", "to ask the Minister", text)
    text = re.sub("the.Minister", "the Minister", text) 
    text = re.sub("BGMET (METFORMIN)", "bgmet (metformin)", text)
    text = re.sub("Itezhi-Tezhi", "Itezhi Tezhi", text)

    if isinstance(text, str):

        url = row['url']
        sections = split_to_sections(text)

        #Check if i in sections has "questions for oral answer"
        for i in range(0, len(sections)):
            if i > 0 and ("oral answer" in sections[i-1].lower() or "written answer" in sections[i-1].lower()):
                sec = sections[i] #for debug
                questions = split_to_questions(sections[i])
                #print(url)
                for q in questions:
                    vars = extract_vars(q)
                    question_numbers.append(vars[0])
                    constits.append(vars[1])
                    speakers.append(vars[2])
                    adressees.append(vars[3])
                    texts.append(vars[4])
                    dates.append(row['date'])
                    urls.append(url)
                    full.append(q)
                    #print(vars)
    if url == "https://www.parliament.gov.zm/node/8081": ###Janky day with misformatting
        sections = split_to_sections(text)
        questions = split_to_questions(sections[len(sections)-1])
        for q in questions:
            vars = extract_vars(q)
            question_numbers.append(vars[0])
            constits.append(vars[1])
            speakers.append(vars[2])
            adressees.append(vars[3])
            texts.append(vars[4])
            dates.append(row['date'])
            urls.append(url)
            full.append(q)

    #
    df = pd.DataFrame(
        {'date': dates, 'question_number': question_numbers, 'constit':constits, 'speaker': speakers, 'addressee': adressees, 'text':texts, 'full':full, 'url':urls}
    )

    df = df[df['text'] != "ERROR"]
    df['written'] = [1 if "w" in x.lower() else 0 for x in df['question_number']]

    df.to_csv(path+"questions_zm_split.csv", index=False)

    #Check Mising Days
    #urls = set(corpus['url']) - set(df['url']) #Get the set of urls in corpus not in df_text
    #corpus[corpus['url'].isin(urls)].to_csv(path+"missing_qs_zm.csv", index=False) #Examine this manually
