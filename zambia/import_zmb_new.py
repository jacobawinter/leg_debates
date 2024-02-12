import requests
from bs4 import BeautifulSoup
import re
import pandas as pd
from datetime import date as d
from time import sleep
from tqdm import tqdm

# Get new nodes
# Create list of nodes
h_date = []
h_text = []
h_node = []
h_urls = []
# Get existing data
data_dir = "/Users/jacobwinter/Dropbox/parl_debates_data/zambia_data"

existing = pd.read_csv(data_dir + "/parl_debates_zm_2024_01_16.csv")


# Scrape daily (node) texts
for url in tqdm(existing['url']):
    #sleep(3)
    #print(url)
    text = "ERROR"
    date = "ERROR"
    try:
        requests.get(url) #here for the try catch
        page = requests.get(url)
        soup = BeautifulSoup(page.content, "html.parser")
        date = soup.find("h1", id="page-title").text.strip()
        text_raw = soup.find("div", class_="field-item even")
        text = text_raw.text.strip()
        h_date.append(date)
        h_text.append(text)
        h_urls.append(url)
    except:
        print("Error: "+url)
        h_date.append(date)
        h_text.append(text)
        h_urls.append(url)

df_text = pd.DataFrame(
    {'date': h_date,
     'text': h_text,
     'url': h_urls
     })

# append and resave
today = d.today()
d1 = today.strftime("%Y_%m_%d")

df_text.to_csv(data_dir + "/parl_debates_zm_" + d1 + ".csv")

