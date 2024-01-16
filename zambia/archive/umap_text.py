import pandas as pd
import string
from nltk import word_tokenize
import umap
import umap.plot
import matplotlib.pyplot as plt
from nltk.corpus import stopwords
from nltk.stem.porter import PorterStemmer
from nltk import pos_tag
import pickle
from sklearn.feature_extraction.text import CountVectorizer, TfidfVectorizer
from bokeh.plotting import show, save, output_notebook, output_file
from bokeh.resources import INLINE
porter = PorterStemmer()
stop_words = stopwords.words('english')
import seaborn as sns

#
# corpus = pd.read_csv("raw_data/matched_speeches_v1.csv") #All agreement types
#
#
# def preprocess(input):
#     text = input.lower()
#     text_p = "".join([char for char in text if char not in string.punctuation])
#     words = word_tokenize(text_p)
#     stop_words = stopwords.words('english')
#     filtered_words = [word for word in words if word not in stop_words]
#     porter = PorterStemmer()
#     stemmed = [porter.stem(word) for word in filtered_words]
#     pos = pos_tag(filtered_words)
#     return stemmed #words, filtered_words, stemmed, pos
#
# corpus['stemmed'] = corpus['text'].apply(preprocess)
#
# #Save Stemmed file
# file = open('stemmed_corpus.pkl', 'wb')
# pickle.dump(corpus, file)
# file.close()

file = open('stemmed_corpus.pkl', 'rb')
corpus = pickle.load(file)
file.close()
corpus = corpus[corpus.party.notnull()]
corpus['party'] = corpus['party'].astype(object)
print(f'{len(corpus["party"])} categories')

vectorizer = CountVectorizer(min_df=5, stop_words='english')

#print(corpus['stemmed'][1:10])
word_doc_matrix = vectorizer.fit_transform(corpus['text'])

embedding = umap.UMAP(n_components=2, metric='hellinger').fit(word_doc_matrix)

f = umap.plot.points(embedding, labels=corpus['party'])

#TFIDF
tfidf_vectorizer = TfidfVectorizer(min_df=5, stop_words='english')
tfidf_word_doc_matrix = tfidf_vectorizer.fit_transform(corpus['text'])
tfidf_embedding = umap.UMAP(metric='hellinger').fit(tfidf_word_doc_matrix)

fig = umap.plot.points(tfidf_embedding, labels=corpus['party'])
#https://github.com/lrheault/partyembed/blob/master/partyembed/explore.py