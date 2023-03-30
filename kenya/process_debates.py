import os, string
from pdfminer.pdfinterp import PDFResourceManager, PDFPageInterpreter
from pdfminer.converter import TextConverter
from pdfminer.layout import LAParams
from pdfminer.pdfpage import PDFPage
from io import StringIO
from tqdm import tqdm

def convert_pdf_to_txt(path):
    #print("processing" + path)
    rsrcmgr = PDFResourceManager()
    retstr = StringIO()
    codec = 'utf-8'
    laparams = LAParams()
    device = TextConverter(rsrcmgr, retstr, codec=codec, laparams=laparams)
    fp = open(path, 'rb')
    interpreter = PDFPageInterpreter(rsrcmgr, device)
    password = ""
    maxpages = 0
    caching = True
    pagenos=set()

    for page in PDFPage.get_pages(fp, pagenos, maxpages=maxpages, password=password,caching=caching, check_extractable=True):
        interpreter.process_page(page)

    text = retstr.getvalue()

    fp.close()
    device.close()
    retstr.close()
    return text

# Covert files
path = "/Users/jacobwinter/Dropbox/parl_debates_data/kenya_data/"


for filename in tqdm(os.listdir(path +"kenya_hansard_raw/")):
    n = filename[:-4]
    if os.path.isfile(path + "kenya_hansard_txt/" + n+".txt"): #Skips any existing docs in file (allows to rerun faster if loop fails)
        continue
    else:
        if filename.endswith(".pdf"):
            try:
                file = path + "kenya_hansard_raw/" + filename
                t = convert_pdf_to_txt(file)
                f = open(path + "kenya_hansard_txt/" + n +".txt", "x")
                f.write(t)
            except:
                continue