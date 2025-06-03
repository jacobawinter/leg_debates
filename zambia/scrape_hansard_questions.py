from tqdm import tqdm
import re
import pandas as pd
from datetime import datetime, date

def extract_vars(question_raw, speakers):
    #The beginning of each string is an all caps string with a number and a dot
    question_header_match = re.search(r"([\s\xa0]*[A-Z0-9\W]{2,}\n[\s\xa0]*[Ww0-9]+.)", question_raw)

    try:
        title = re.search(r'[\s\xa0]*[A-Z0-9\(\)\- ]+',question_header_match[0])
        title = re.sub("\n", " ", title[0])
    except:
        title = "ERROR"
    
    try:
        number = re.search(r'([Ww0-9]+\.)',question_header_match[0])
        number = re.sub("\.", "", number[0])
    except:
        number = "ERROR"

    question = re.split(f'{number}\.',question_raw)
    question = [' '.join(question[1:])] #In case there happens to be an identical matching number

    #First, get the things before 'asked', which is the speaker's name and constituency
    split = re.split(r"asked|to ask", question[0], flags=re.IGNORECASE) #Split on the first line with a capital letter and a colon, which is usually the respondent's name
    speaker = split[0].strip() #The first part is the speaker's name and constituency
    #Strip Mr, Mrs,Dr from the beginning of the speaker's name
    speaker = re.sub(r"^(Mr|Mrs|Dr|Ms|Hon|Col)\.?\s+", "", speaker, flags=re.IGNORECASE)

    remainder = [' '.join(split[1:])] #The rest is the question text and the respondent's name
    remainder_split = re.split(r"(\n.*?mr speaker|\n.*?mr\. speaker|\n.*?madam speaker)", remainder[0], flags=re.IGNORECASE)
    query = remainder_split[0].strip() #The first part is the question text
    try:
        respondent = remainder_split[1].strip() #The first part is the respondent's name
        respondent = re.sub("mr speaker|mr\. speaker|madam speaker", "", respondent, flags=re.IGNORECASE) #Remove the colon at the end of the respondent's name
    except:
        respondent = "ERROR" #If there is no respondent, set to ERROR    
    
    response = [' '.join(remainder_split[1:])]

    # if len(split) < 3:
    #     #Check for "behalf"
    #     split = re.split(r"(\n[A-Z][\w\s\.\'\-\,]*\([^:\n]*on behalf of[^:\n]*\)|\n[A-Z][\w\s\.\'\-\,]*\([^)]*\)):", question[0])
    # if len(split) < 3:
    #     split = re.split(r"([A-Z][\w\s\.\'\-\,]*):", question[0])
            
    # if len(split) < 3:
    #     return {
    #         "title": title,
    #         "number": number,
    #         "question": question[0],
    #         "constit": "ERROR",
    #         "speaker": "ERROR",
    #         "adressees": "ERROR",
    #         "text": "ERROR",
    #         "respondent": "ERROR",
    #         "response": "ERROR"
    #     }
    # else:
    #     query = split[0] #Question text -- to extract name, constituency, minister
    #     respondent = split[1] #Respondent name
    #     response = split[2]
    try:
        constit = re.findall('\([A-z\s\-]{3,}\)',speaker)[0] #Constituency is in brackets
        constit = re.sub("\(|\)","", constit.lower())        
    except:
        try: #If there is no constituency match, go back and match surname from the rest of the text
            if 'behalf' in re.split(r' ', speaker):
                speaker = re.split(r' ', speaker)[-1] #Take last name if "behalf" is in the speaker's name


            elif len(re.split(r' ', speaker)) > 1: #Check if there are multiple names, take second
                speaker = re.split(r' ', speaker)
                speaker = [re.sub(r'[^\w\s\:]', '', w) for w in speaker if w != 'behalf'] #Remove punctuation
                speaker = [w for w in speaker if len(w) > 3] #Remove single letter words
                
                try:
                    speaker = speaker[1] #Take second name
                except:
                    speaker = speaker[0]

            constit = next((item for item in speakers if re.sub(r'[^\w\s]', '', speaker) in item), None)
            constit = re.sub(speaker,"", constit)
            constit = re.sub(" \(|\)","", constit.lower()) #If there is no constituency match, go back and match surname from the rest of the text
        except:
            constit = "ERROR"
    try:
        adressees_full = re.findall('.*?(?=how|when|why|what|whether|who|[.:!?\(\n])', query)
        adressees = adressees_full[0]
        if adressees == "the hon":
            adressees = adressees_full[2] #If the first match is "the hon", take the second match

    except:
        adressees = "ERROR"

    try:
        try:
            text = re.split(adressees, query)
            text = [' '.join(text[1:])]
            text = re.sub("\n", " ", text[0])
            text = re.sub("  ", " ", text)
        except:
            try:
                text = re.split(r':', query)
                text = [' '.join(text[1:])]
                text = re.sub("\n", " ", text[0])
                text = re.sub("  ", " ", text)
            except:
                text = query

    except:
        text = "ERROR"

    return {
        "title": title,
        "number": number,
        "question": question,
        "constit": constit,
        "speaker": speaker,
        "adressees": adressees,
        "text": text,
        "respondent": respondent,
        "response": response
    }

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

def split_questions(text_raw, url):
    # Split on all caps "QUESTIONS FOR" and cut everything above
    try:
        text = text_raw.split('QUESTIONS FOR')[1]
    except:
        #print(f"No 'QUESTIONS FOR' found for {url}")
        return None
    text = re.split(r'_+\s*\n[A-Z\s]+\n', text)[0] #Get rid of stuff after questions Usually _____\nMOTIONS

   # pattern = r'(?=^[A-Z0-9 ,;:\-\(\)]+\n\d+\..*)|(?=^[A-Z0-9 ,;:\-\(\)]+\n\xa0\n\d+\..*)|(?=^[A-Z0-9 ,;:\-\(\)]+\n\xa0\d+\..*)'
    #pattern = r'(?=^[A-Z0-9 ,;:\-\(\)]+\s*\n[\s\xa0]*\d+\.)'
    pattern = r'(?=^[\s\xa0]*[A-Z0-9 ,;:\-\(\)]+\s*\n[\s\xa0]*\d+\.)' #Check for space or tab before caps

    # Split the text using the regex
    chunks = re.split(pattern, text, flags=re.MULTILINE)

    # Output 
    # for i, chunk in enumerate(chunks, 1):
    #     print(f"--- CHUNK {i} ---")
    #     print(chunk)
    #     print()
    
    if "QUESTIONS FOR WRITTEN" in text_raw:
        text_written = text_raw.split('QUESTIONS FOR WRITTEN')[1]

        pattern_w = r'(?=^[A-Z0-9 ,;:\-\(\)]+\nW\d+\..*)'
    
        chunks_written = re.split(pattern_w, text_written, flags=re.MULTILINE)
        chunks = chunks + chunks_written[1:]

    chunks = [chunk.strip() for chunk in chunks if chunk.strip()][1:]

    return chunks


if __name__ == "__main__":

    titles = []
    questioners = []
    constits = []
    question_numbers = []
    adressees = []
    texts = []
    respondents = []
    responses = []
    dates = []
    urls = []
    full= []


    path = "/Users/jacobwinter/Dropbox/parl_debates_data/zambia_data/"
    file = "parl_debates_zm_2024_01_22.csv"
    corpus = pd.read_csv(path+file) #All agreement types

    #corpus = corpus[corpus['url']=="https://www.parliament.gov.zm/node/11152"]
    corpus = corpus[corpus['text'] != "ERROR"]

    corpus = remove_duplicates = corpus.drop_duplicates(subset=['date'], keep='first')
    #corpus = corpus[corpus['text'].str.contains("QUESTIONS FOR WRITTEN")]

    chunkcount = 0
    for index, row in tqdm(corpus.iterrows(), total=corpus.shape[0]):
        text= row['text']
        text = re.sub("’","", text) #Fix some typing errors manually
        text = re.sub("to the Minister", "to ask the Minister", text)
        text = re.sub("the.Minister", "the Minister", text) 
        text = re.sub("BGMET (METFORMIN)", "bgmet (metformin)", text)
        text = re.sub("Itezhi-Tezhi", "Itezhi Tezhi", text)
        if isinstance(text, str):
            text = re.sub("{mospagebreak}","", text) #get rid of this artefact as it can mess up identifying headers
            
            date = extract_date(row['date'])

            speakers = re.findall('[A-Z]{1}[a-z]+ \([A-z ]+\)', text)


            try:
                chunks = split_questions(text, row['url'])
                chunkcount = chunkcount + len(chunks)
                if len(chunks) == 0:
                    print(f"Empty chunk for {row['url']} on {row['date']}")
            except:
                continue
            if len(chunks) > 0:
                for chunk in chunks:
                    vars = extract_vars(chunk, speakers)
                    question_numbers.append(vars['number'])
                    constits.append(vars['constit'])
                    questioners.append(vars['speaker'])
                    adressees.append(vars['adressees'])
                    texts.append(vars['text'])
                    respondents.append(vars['respondent'])
                    responses.append(vars['response'])
                    titles.append(vars['title'])
                    dates.append(date)
                    urls.append(row['url'])
                    full.append(chunk)
                

    df = pd.DataFrame(
        {'date': dates, 'question_number': question_numbers, 'title': titles, 'constit':constits, 'speaker': questioners, 'text':texts, 'addressee': adressees,
        'respondent': respondents, 'response': responses, 'full':full, 'url':urls}
    )

    df['written'] = [1 if "w" in x.lower() else 0 for x in df['question_number']]

    df['has_error'] = df.eq('ERROR').any(axis=1)
    print(df['has_error'].value_counts())

    today = datetime.today()
    today = today.strftime("%Y_%m_%d")
    df.to_csv(f"{path}/questions_zm_from_hansard_{today}.csv", index=False)