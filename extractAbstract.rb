#!/usr/bin/ruby
# coding: utf-8
require 'csv'
require 'open-uri'
require './mecabFreq'
require './posterCorrelation'
require './posterGraph'

filePath = "posterFile.csv"
posters = nil #要約を回収
entry = nil
  
if false #ファイルを読み直すときはtrueを指定
  source = CSV.readlines(filePath) #ファイル読込み
  noOverlap = Hash.new #同じ登録番号を無視する
  
  source.slice(1..-1).each do |parts|
    entry = Array.new
    entry.push(parts[1]) #プログラム番号
    entry.push(parts[2]) #日本語タイトル
    entry.push(parts[12]) #発表者
    entry.push(parts[4]) #要旨
  	
    if entry[1] =~ /[^\w ]/ || entry[3] =~ /[^\w ]/
      noOverlap[parts[0].to_i] = entry #登録番号でハッシュ
    end
  end
	
  posters = noOverlap.values #値だけの配列を取得
  file = open("./data/posterAbstract.txt", "w")

  posters.each do |poster|
    file.write("#{poster[0]}；#{poster[2]}\n")
    file.write("#{poster[1]}\n#{poster[3]}\n\n")
  end

  file.close
  puts "Wrote the contents."
else
  file = open("./data/posterAbstract.txt", "r:utf-8")
  posters = Array.new

  while line = file.gets
    temp = Array.new
    string = line.chomp.split("；")
    temp.push(string[0]) #プログラム番号
    temp.push(file.gets.chomp) #日本語タイトル
    temp.push(string[1]) #発表者
    temp.push(file.gets.chomp) #要旨
    posters.push(temp)
    file.gets
  end

  file.close
  puts "Got contents from the file."
end

if false #頻度を取り直すときはtrue
  mecabFreq = MecabFreq.new
  #freq = mecabFreq.allFreq(posters)
  freq = mecabFreq.eachFreq(posters)

  file = open("./data/posterFreqBorder.txt", "w")

  freq.each do |word| #単語名と出現頻度を出力
    file.write("#{word[0]}\t#{word[1]}\n")
  end

  file.close
=begin
  freq = mecabFreq.eachFreq(posters)
	
  file = open("./data/posterFreqEach.txt", "w")
	
  freq.each do |poster|
    poster.each do |parts|
      file.write("#{parts[0]}\t#{parts[1]}\t")
    end
		
    file.write("\n")
  end
	
  file.close
=end
  puts "Wrote the words frequency."
else
  file = open("./data/posterFreqBorder.txt", "r:utf-8")
  freq = Array.new
	
  while line = file.gets
    temp = Array.new
    line = line.chomp.split(/\t/)
    temp.push(line[0])
    temp.push(line[1].to_i)
    freq.push(temp)
  end
	
  file.close
  puts "Read the words frequency."
end

correlation = PosterCorrelation.new(posters, freq)
correlation.dumpToFile("./data/posterCorrelation.sif")
#graph = PosterGraph.new(correlation.posterDistance)
#graph.graphviz("./data/posterCorrelation")
puts "Wrote the correlation."
