# coding: utf-8
require "rubygems"
require "kconv"

class PosterCorrelation
  attr_reader :posterDistance
  @@lowerFreq = 100 #出現頻度が一定以下の単語は無視
  @@upperPosters = 100 #単語を含むポスター数が一定以上の単語は破棄
  
  def initialize(posters, wordFreq)
    correlation = Array.new #ここに同じ単語が出現するポスター番号を回収
    
    wordFreq.each_with_index do |word, i|
      print "\r#{i + 1}"
      posterNumber = Array.new
      posterNumber.push(word) #まず単語名と出現頻度を回収

      if word[0] =~ /^[\w\-]+$/ #英単語だけ
        wordExp = /[^\w\-]#{word[0]}[^\w\-]|^#{word[0]}[^\w\-]|[^\w\-]#{word[0]}$/
      elsif word[0] =~ /^[ァ-ヶ]+$/ #カタカナだけ
        wordExp = /[^ァ-ヶ]#{word[0]}[^ァ-ヶ]|^#{word[0]}[^ァ-ヶ]|[^ァ-ヶ]#{word[0]}$/
      else
        wordExp = /#{Regexp.escape(word[0])}/
      end
      
      posters.each do |poster|
        if poster[1] =~ wordExp or poster[3] =~ wordExp
          posterNumber.push([poster[0], poster[2]]) #タイトル・要旨に単語を含めばプログラム番号と発表者を追加
          #end
        end
      end
      
      if posterNumber.length > 2 and posterNumber.length < @@upperPosters #2つ以上ポスター番号が含まれているものを出力
        correlation.push(posterNumber) #共起リストを追加
      end
        
      if word[1] < @@lowerFreq
        break
      end
    end

    file = open("./data/wordCorrelation.txt", "w:utf-8")
    #単語が出現したポスターをファイルに保存
    correlation.each do |posterNumber|
      file.write("#{posterNumber.first}: ")
    
      posterNumber.slice(1..-1).each do |number|
        file.write("[#{number[0]}, #{number[1]}]\t")
      end
      
      file.write("\n")
    end
    
    file.close
    puts
    #ポスター相関を計算
    @posterDistance = Hash.new #ここにポスター間距離を回収
    #correlation = [[[単語名, 出現頻度], [プログラム番号, 発表者], [], ...], ...]
    correlation.each_with_index do |posterNumber, pivot|
      print "\r#{pivot + 1}/#{correlation.length}"
      
      posterNumber.slice(1..-1).each_with_index do |poster, i| #プログラム番号列
        if !@posterDistance.include?(poster)
          @posterDistance[poster] = Hash.new
        end
        
        posterNumber.slice(1..-1).slice((i + 1)..-1).each do |target|
          if !@posterDistance[poster].include?(target)
            @posterDistance[poster][target] = Array.new #存在しなければ新たに追加
            @posterDistance[poster][target].push(posterNumber.first) #単語名を追加
          else #存在すれば単語追加
            @posterDistance[poster][target].push(posterNumber.first)
          end
        end
      end
      
    end
    #@posterDistance = [[ポスター, [[ポスター, [共出現単語, ...]], ...]], ...]
    mirrorDistance = Hash.new #相手としてしか登録されていないポスターを回収
    
    @posterDistance.each do |posterNumber, target|
      target.each do |poster, words| #相手のポスター名と単語
        if !@posterDistance.include?(poster) #相手ポスターがメインハッシュに無い
          if !mirrorDistance.include?(poster)
            mirrorDistance[poster] = Hash.new
          end
          #新規登録用ハッシュに保存
          mirrorDistance[poster][posterNumber] = words
        else
          @posterDistance[poster][posterNumber] = words
        end
      end
    end
    #プログラム番号の小さい順に並び替え
    @posterDistance.merge!(mirrorDistance)
    @posterDistance = @posterDistance.sort{|a, b| a[0][0] <=> b[0][0]}
  end
  
  def dumpToFileWithHTML(fileName, html)
    file = open(fileName, "w")
    file2 = open(fileName + "sub", "w")
    file3 = open(fileName + "com", "w")
    
    @posterDistance.each do |posterNumber, numberHash|
      file.write("[#{posterNumber[0]}, #{posterNumber[1]}]\tpp\t".tosjis) #元のポスター出力
      file2.write("[#{posterNumber[0]}, #{posterNumber[1]}]\n")
      limits =3 #最大出力相関ポスター数
      numberHash = numberHash.sort{|a, b| b[1].length <=> a[1].length} #共有単語数の多い順に並べ替え
      
      numberHash.each do |number, words|
        file2.write("[[#{number[0]}, #{number[1]}]: ")
        words = words.sort{|a, b| b[0].length <=> a[0].length}
        freqAll = 0 #相関単語の全頻度値合計
        
        words.each do |word|
          file2.write("#{word[0]}, ")
          
          if word[0] =~ /a-zA-Z/ #英語は頻度を下げる
            word[1] /= word[0].length
          end
          
          freqAll += word[1]
        end
        
        file2.write("#{freqAll}]\n")
      end
      
      lastLength = nil
      rank = limits
      rankScore = [0, 10, 30, 50, 70]
      
      numberHash.each do |number, words|
        if limits <1 and words.length != lastLength
          break #同順位で無くなったら抜ける
        end
        
        if words.length != lastLength
          rank = limits #順位を更新
        end
        
        if words.length >0  and posterNumber[0] < number[0]
          file.write("[#{number[0]}, #{number[1]}]\t".tosjis)
          file3.write("[#{posterNumber[0]}, #{posterNumber[1]}]\t[#{number[0]}, #{number[1]}]\t")
          
          if limits >1
            file3.write("#{rankScore[rank - 1] + words.length * 2}\n")
          else
            file3.write("#{rankScore[0] + words.length * 2}\n")
          end
          
          words.each do |word|
            html.gsub!(word[0], "<u>#{word[0]}</u>")
          end
        end
        
        limits -=1
        lastLength = words.length #前回の単語数を記憶しておく
      end
      
      file.write("\n")
      file2.write("\n")
    end
    
    puts
    file.close
    file2.close
    file3.close
    
    if !(html.empty?)
      file = open("./data/source.html", "w")
      file.write(html)
      file.close
    end
    
    puts "Wrote the correlation."
  end
  
  def dumpToFile(fileName)
    dumpToFileWithHTML(fileName, "") #HTMLなしで呼び出す
  end
end
