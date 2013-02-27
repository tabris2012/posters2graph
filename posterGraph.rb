# coding: utf-8
require "fileutils"
require "rubygems"
require "parallel"
require "gviz"


class PosterGraph
  def initialize(distance)
    @posterDistance = distance
    @rank = 2
    @depth = 4
    @nodes = 5 #最大出力ノード数
    @percent = 0.8 #最低上位%
    @fonts = [14, 15, 16, 18, 30]
  end
  
  def makeIdealEdges(posterSearch, gviz, idealNodes, depth)
    posterHash = @posterDistance[posterSearch].sort{|a, b| b[1].length <=> a[1].length}
    lastLength = posterHash[0][1].length #始めの共有単語数
    toDraw = Array.new #出力予定ポスターを回収
    #まず共有単語数の一番多いポスターをすべて回収
    posterHash.each do |number, words|
      if words.length != lastLength #同順でなくなったら
        lastLength = words.length
        break
      end
      
      toDraw.push([number, words.last.to_i]) #wordsの最後に頻度合計値が入っている
      lastLength = words.length #前回の単語数を記憶しておく
    end


    if toDraw.length > idealNodes#既に理想出力数を超えていたら 
      toDraw = toDraw.sort{|a, b| a[1] <=> b[1]} #単語頻度の小さい順に入れ替え
      toDraw = toDraw.slice(0, idealNodes) #理想出力数まで出力


      toDraw.each do |number, words| #理想出力数まで出力
        gviz.route :"p#{posterSearch[0].gsub(/\-/, "")}" => :"p#{number[0].gsub(/\-/, "")}"
        
        if depth == @depth #まだ深くなければ
          makeIdealEdges(number, gviz, depth -2, depth - 1)
        end
      end


      toDraw.each do |number, words|  
        gviz.node :"p#{number[0].gsub(/\-/, "")}", label:"#{number[0]}:#{number[1]}", fontsize:@fonts[depth -1], color:depth
      end
    else #届いていなければさらに追加
      drawnNodes = toDraw.length #既に出力したノード数を記録
      toDraw = 0 #同順位のポスター数を数える


      posterHash.slice(drawnNodes..-1).each do |number, words|
        if words.length != lastLength #同順位でなくなったら
          if (toDraw + drawnNodes) > idealNodes #出力上限数を超えていれば
            break
          else #上限を超えていなければ
            drawnNodes += toDraw #出力予定数を追加
            toDraw =0
          end
        end


        toDraw +=1
        lastLength = words.length #前回の単語数を記憶しておく
      end
      #最後に全て出力
      posterHash.slice(0, drawnNodes).each do |number, words|
        gviz.route :"p#{posterSearch[0].gsub(/\-/, "")}" => :"p#{number[0].gsub(/\-/, "")}"
        
        if depth >1
          makeIdealEdges(number, gviz, idealNodes - drawnNodes + depth -2, depth - 1)
        end
      end
      
      posterHash.slice(0, drawnNodes).each do |number, words|
        gviz.node :"p#{number[0].gsub(/\-/, "")}", label:"#{number[0]}:#{number[1]}", fontsize:@fonts[depth -1], color:depth
      end
    end
  end
  
  def makePercentEdges(posterSearch, gviz, percent, depth) #上位%だけグラフ描画
    #posterHash = @posterDistance[posterSearch].sort{|a, b| b[1][1] <=> a[1][1]} #スコアの高い順に並び替え
    if !(posterHash = @posterDistance[posterSearch])
      return
    end


    cutoff = posterHash[0][1][1] * percent #足切りスコアを計算
    toDraw = 0 #出力個数を数える


    posterHash.each do |number, score|
      if score[1] < cutoff
        break #足切り点に達したら終了
      end


      toDraw += 1
    end


    posterHash = posterHash.slice(0, toDraw)


    posterHash.each do |number, score|
      gviz.route :"p#{posterSearch[0].gsub(/\-/, "")}" => :"p#{number[0].gsub(/\-/, "")}"
      #toDraw番目のスコアを最大スコアで割った割合で呼び出す
      if depth >1
        makePercentEdges(number, gviz, posterHash[toDraw - 1][1][1] / posterHash[0][1][1], depth - 1)
      end
      #深さ探索前のエッジにラベルをつける
      if depth == @depth
        gviz.edge :"p#{posterSearch[0].gsub(/\-/, "")}_p#{number[0].gsub(/\-/, "")}", headlabel:"#{score[0]}", fontsize:30, fontcolor:"red"
      end
    end
    #まとめて書式設定
    posterHash.each do |number, score|
      gviz.node :"p#{number[0].gsub(/\-/, "")}", label:"#{number[0]}:#{number[1]}", fontsize:@fonts[depth -1], color:depth
    end
  end


  def makeScoreEdges(posterSearch, gviz, nodes, depth) #指定ノード数だけグラフ描画
    #posterHash = @posterDistance[posterSearch].sort{|a, b| b[1][1] <=> a[1][1]} #スコアの高い順に並び替え
    if !(posterHash = @posterDistance[posterSearch])
      return
    end


    posterHash = posterHash.slice(0, nodes)
    nextDepth = depth - 1
    
    if posterHash.last[1][1] / posterHash[0][1][1] > 0.7 #設定値より大きければ出力数変更
      nodes = @nodes - @depth + depth -1
    else #探索深度をさらに減らす
      nextDepth -= 1
    end


    posterHash.each do |number, score|
      gviz.route :"p#{posterSearch[0].gsub(/\-/, "")}" => :"p#{number[0].gsub(/\-/, "")}"


      if nextDepth >1 and nodes >0
        makeScoreEdges(number, gviz, nodes, nextDepth)
      end
      #深さ探索前のエッジにラベルをつける
      if depth == @depth
        gviz.edge :"p#{posterSearch[0].gsub(/\-/, "")}_p#{number[0].gsub(/\-/, "")}", headlabel:"#{score[0]}", fontsize:26, fontcolor:"red"
      end
    end
    #まとめて書式設定
    posterHash.each do |number, score|
      gviz.node :"p#{number[0].gsub(/\-/, "")}", label:"#{number[0]}:#{number[1]}", fontsize:@fonts[depth -1], color:depth, URL:"#{number[0]}.svg"
    end
  end


  def allPosterGraph()
    posterSearch = nil #中心となるポスターを探す
    dir = "./posters/#{@depth}"
    FileUtils.mkpath(dir) unless FileTest.exist?(dir)
    limit =3


    #Parallel.map(@posterDistance) do |posterHost, target| #無制限並列化により相関画像出力
    @posterDistance.each do |posterHost, target| #全てのポスターについて相関画像出力  
      gv = Gviz.new
      gv.global layout: 'neato', overlap: false, splines: true #neato, twopi
      gv.edges arrowhead: 'none'
      gv.nodes style: "filled", colorscheme:"blues5"
      
      #makeIdealEdges(posterHost, gv, @nodes, @depth)
      makeScoreEdges(posterHost, gv, @nodes, @depth)
      gv.node :"p#{posterHost[0].gsub(/\-/, "")}", label: "#{posterHost[0]}:#{posterHost[1]}", style:"bold", fontsize:@fonts[4], penwidth:5, color:"black"
      gv.save("#{dir}/#{posterHost[0]}", :svg)
      
      print "\r#{posterHost[0]}"
      limit -=1
      
      if limit < 0
        break
      end
    end


    puts
  end
  
  def graphviz(fileName)
    gv = Gviz.new
    
    gv.global layout: 'neato', overlap: false
    gv.edges arrowhead: 'none'
    i =0
      
    @posterDistance.each do |posterHost, posterHash|
      i +=1
      print "\r#{i}/#{@posterDistance.length}"
      limit = 1
      posterHash = posterHash.sort{|a, b| b[1].length <=> a[1].length}
      lastLength = nil
        
      posterHash.each do |number, words|
        if limit < 1 and words.length != lastLength
          break
        end
        
        if words.length > 0  and posterHost[0].to_i < number[0].to_i
          gv.route "#{posterHost[0]}".to_sym => "#{number[0]}".to_sym
          gv.node "#{number[0]}".to_sym, label: number[1]
        end
          
        limit -= 1
        lastLength = words.length #前回の単語数を記憶しておく
      end
        
      gv.node "#{posterHost[0]}".to_sym, label: posterHost[1]
    end
    
    puts
    puts "Graph mapping ready."
    gv.save(fileName, :png)
    puts "Graph has output."
  end
end
#以下エントリーポイント
#ポスター相関を読込んで全発表者について画像を作成する
if __FILE__ == $0
  rank = 20 #読込む最大ランク数
  posterDistance = Hash.new
  file = open("./data/posterCorrelation.sifsub")
  i = 0
  #相関ファイルのパース
  while line = file.gets
    if line.chomp! != ""
      i += 1
      print "\r#{i}"
      line = line.split(/\[|\]|\, /)
      poster = Array.new
      poster.push(line[1]) #プログラム番号回収
      poster.push(line[2]) #発表者回収
      posterDistance[poster] = Hash.new
      limit = rank #読み込み上位数を指定
      lastLength = nil
    
      while line = file.gets
        if line.chomp! == ""
          break #相関対象終了
        end
      
         line = line.split(/\[|\]|\, |: /)
      
        if limit < 1 and line.length != lastLength
          next #同順位で無くなったらそのままループ
        end
        
        target = Array.new
        target.push(line[2])
        target.push(line[3])
        posterDistance[poster][target] = line.slice(5..(line.length - 1)) #相関する単語を全て回収
        limit -= 1
        lastLength = line.length #前回の単語数を記憶しておく
      end
    end
  end


  puts
  
  file.close
  graph = PosterGraph.new(posterDistance)
  graph.allPosterGraph
end
