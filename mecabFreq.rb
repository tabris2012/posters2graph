# coding: utf-8
require 'MeCab'

class MecabFreq
  def initialize() #必要ならここでユーザ辞書を指定。"-u /home/userDic.dic"
    @tagger = MeCab::Tagger.new("-u /home/userDic.dic")
    @toDelete = Array.new
    file = open("./data/toDelete.txt", "r:utf-8")
    #追加禁止語読込み
    while line = file.gets
      @toDelete.push(line.chomp)
    end
  end

  def addWordFromMecab(text, freq) #textをMeCabで切断しHashに登録
    string = "" #ハッシュに追加する文字列
    alflag = false #英単語フラグ
    text.gsub!(/<[^>]+>/, "") #タグを除去
  
    n = @tagger.parseToNode(text)

    while n = n.next do
      surface = n.surface.force_encoding("utf-8")
      feature = n.feature.force_encoding("utf-8")
      
      if feature !~ /名詞|アルファベット/ or  feature =~ /非自立|代名詞|形容|副詞|地域/ or surface =~ /[\(\)\[\]），～]/
        if !string.empty? and string !~ /^[\d,]+$|^[\w.ぁ-ヶ０-９]$|^http:|^&|;$/
          pushFlag = true
          
          @toDelete.each do |word|
            if word =~ /#{Regexp.escape(string)}/
              pushFlag = false
              break
            end 
          end
          
          if pushFlag
            if freq.include?(string) #既に追加済なら
              freq[string][0] +=1
            elsif string =~ /[a-zA-Z]/ #新規登録
              freq[string] = [string.length * 4, 0]
            else
              freq[string] = [1, 0]
            end
          end
        end
        
        string = ""
        alflag = false
        next
      end
      #追加単語の作成
      if surface == "。"
        string = ""
        alflag = false
        next
      end
      
      if !string.empty? and surface =~ /^([0-9,]+)$/ and n.next.feature.force_encoding("utf-8") =~ /助数/
        n = n.next #数→助数詞などは、まず１単語飛ばす
        
        while n.next.feature.force_encoding("utf-8") =~ /接尾|サ変/ #さらに飛ばす
          n = n.next 
        end
        
        next
      end
      
      if surface =~ /^[a-zA-Z]/ #英単語は、スペースを入れてつなげる
        if alflag and surface.length >1 #前の単語が英単語だった
          string += " "
        else
          alflag = true;
        end
      elsif surface !~ /^(\d+)$/ or string.length >3 #数字のときはフラグを残す
        alflag = false
      end
      
      if string.empty?
        if feature =~ /サ変接続/ and n.next
          if n.next.feature.force_encoding("utf-8") !~ /名詞/ or n.next.feature.force_encoding("utf-8") =~ /サ変接続|語幹/
            next # $stringが空で、$nがサ変接続で、$n->nextが名詞でなかったら
          end
        elsif feature =~ /接尾/
          if n.prev.feature.force_encoding("utf-8") =~ /固有/ #一つ前が固有名詞なら追加
            string = n.prev.surface.force_encoding("utf-8") + surface
          end
          
          next   #$stringが空で、$nが接尾属性を持つなら
        end
      end

      if feature =~ /名詞接続/
        string += surface
        string += n.next.surface.force_encoding("utf-8")
        n = n.next
        next
      end

      string += surface
    end
  end
  
  def correctFreq(freq, report) #頻度ハッシュを補正する
    freq = freq.sort{|a, b| a[0].length <=> b[0].length} #短い順に並べ替え
    #ある単語を中に含むものを調べる
    freq.each_with_index do |key, i|
      if report
        print "\r#{i + 1}/#{freq.length}"
      end
      
      keyEscape = Regexp.escape(key[0])
      
      freq.slice((i + 1)..-1).each_with_index do |target, j|
        if target[0] =~ /\W#{keyEscape}\W|^#{keyEscape}\W|\W#{keyEscape}$/ #両端英数字マッチを除く
          #target[1][1] += key[1][0] #内包分用セグメントに加算
          key[1][1] += target[1][0]
        end
      end
    end
    #頻度値をまとめる
    freq.each do |key|
      key[1] = key[1][0] + key[1][1]
    end

    freq = freq.sort{|a, b| b[1] <=> a[1]} #値の大きい順に並び替え
    return freq
  end
  
  def allFreq(textArray)
    freq = Hash.new #単語リスト
    limit =0
    
    textArray.each do |text|
      limit += 1
      if limit > 10
        break
      end
      
      print "\r#{limit}/#{textArray.length}"
      addWordFromMecab(text[1] + "\n" + text[3], freq)
    end
          
    puts
    freq = correctFreq(freq, true)
    puts
    return freq
  end
  
  def eachFreq(textArray)
    freqArray = Array.new
    limit =0
    
    textArray.each do |text|
      limit += 1
      #if limit > 50
      # break
      #end
      
      print "\r#{limit}/#{textArray.length}"
      freq = Hash.new
      addWordFromMecab(text[1] + "\n" + text[3], freq)
      freqArray.push(correctFreq(freq, false)) #文章ごとに頻度値を回収
    end
    
    puts
    #return freqArray
    freqAll = Hash.new
    
    freqArray.each do |freq|
      freq.each do |text|
        if text[1] <2 #頻度値が2を下回ったら次のポスターへ
          break
        end
        
        if freqAll.include?(text[0])
          freqAll[text[0]][0] += text[1]
        else #新規登録
          freqAll[text[0]] = [text[1], 0]
        end
      end
    end
    
    freqAll = correctFreq(freqAll, true)
    puts
    return freqAll
  end
end
