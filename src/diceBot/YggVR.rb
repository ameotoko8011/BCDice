# -*- coding: utf-8 -*-

class YggVR < DiceBot
  setPrefixes([
     'H?CF.*', 'H.*', 'RA.*', 'SO.*', 'DOWN', 'CO(NT)?',
    'RISK', 'GUKI', 'COND', 'TREAT.*',
    'ALLR', 'PAFE', 'FATAL.*', 'STAG', 'MIKUZI', 'LL', 'ST'
  ])
  
  def initialize
    super
    @fractionType = "omit";     #端数の処理 ("omit"=切り捨て, "roundUp"=切り上げ, "roundOff"=四捨五入)
  end
  
  def gameName
    '鋼鉄のユグドラシルVR'
  end
  
  def gameType
    "YggVR"
  end
  
  def getHelpMessage
    return <<MESSAGETEXT

用途に合わせて判定式の頭に、以下を記述してください。
cf：クリティカルファンブルアリ
cfl：付加効果【幸運】付与
cfg：付加効果【ギャンブル】付与
ra：暴走ロール。「ra50」のように、暴走レベルに合わせた暴走結果を出力する
so：スペックオーバー判定
down：気絶判定
cont：コンティニュー判定
risk：リスク判定
guki：偶奇判定
cond：コンディションロール
cft/cflt/cfgt：応急処置判定。左から通常判定、幸運判定、ギャンブル判定
treat：応急処置の回復量算出。「treat18」のように達成値を記入する
allr：オールレンジ発動ロール
pafe：パーフェクト発動ロール
fatal：暴走崩壊判定。fatal1で因子変化、fatal2で後遺症決定。あなたがこのコマンドを使用する事がない事を祈っています
MESSAGETEXT
  end
  
  def rollDiceCommand(command)
    case command
      when /H?CF/i
        return '' unless( /(H)?CF([LG])?(T)?([\+\-]?\d+[D\+\-\d+]*)+/i=~ command )
    
        hoge = true if($1 == "H")
        hoge ||= false
        lucky_state = $2
        treat_flg = true if($3 == "T")
        treat_flg ||= false
        #return "1#{hoge} 2#{$2} 3#{$3} 4#{$4}"
        
        dice_mod = []
        dice_mod_text = []
        $4.scan(/([\+\-]?\d+D6|[\+\-]?\d+)/i) { |match| dice_mod << match }
        dice_mod.flatten!
        
        dice_n = []
        diceText = []
        n1 = []
        n_max = []
        #cf未適用一投目
        dice_mod.each_with_index{|num, idx|
          if(num =~ /(\-)(\d+)D6/i)
            dice_n[idx], diceText[idx], = roll($2, 6)
            dice_mod[idx] = "#{$1}#{dice_n[idx]}"
            dice_mod_text[idx] = "#{$1}#{dice_n[idx]}[#{diceText[idx]}]"
          elsif(num =~ /(\+)?(\d+)D6/i)
            dice_n[idx], diceText[idx], n1[idx], n_max[idx], = roll($2, 6)
            dice_mod[idx] = "#{$1}#{dice_n[idx]}"
            dice_mod_text[idx] = "#{$1}#{dice_n[idx]}[#{diceText[idx]}]"
          
          else
            dice_mod_text[idx] = dice_mod[idx]
          end
        }
        #nilを0に変換
        dice_n.map!(&:to_i)
        n1.map!(&:to_i)
        n_max.map!(&:to_i)
        
        #fa数とcr数をそれぞれ合計。cr数は連鎖しても良いように配列にしておく
        n1 = n1.inject(0, :+)
        n_max = [n_max.inject(0, :+)]
        
        if(lucky_state == "L" || lucky_state == "G")
          #幸運状態処理
          lf = diceText.join.split(/,/).count("2")
          lc = diceText.join.split(/,/).count("5")
          n1 += lf
          n_max[0] += lc
        end
        if(lucky_state == "G")
          #ギャンブル状態処理
          gf = diceText.join.split(/,/).count("3")
          gc = diceText.join.split(/,/).count("4")
          n1 += gf
          n_max[0] += gc
        end
        
        #ファンブルロール
        fa1, fa2, = roll(n1, 6)
        
        #クリティカル処理[加算分合計, cr出目, 捨てる変数, crダイス数]
        cr1 = []
        cr2 = []
        roll_re = 0
        while (n_max[roll_re] > 0)
          cr1[roll_re], cr2[roll_re], dummy, n_max[roll_re + 1], = roll(n_max[roll_re], 6)
          roll_re += 1
        end
        #crの達成値を合計する・cr出目を見易く
        cr1 = cr1.inject(0, :+)
        cr2 = cr2.join("][")
        
        #修正値&一投目出目 -ファンブル +クリティカル
        total_n = parren_killer("(0#{dice_mod.join})").to_i - fa1 + cr1
        total_n /= 2 if(hoge == true)
        #最終達成値
        result = "計【 #{total_n} 】"

        text = "(#{command}) ＞ #{result} ： #{dice_mod_text.join(" ")}"
        #クリファン有無に応じて表示の追加
        text += " (fa:#{n1})-#{fa1}[#{fa2}]" if (n1 > 0)
        text += " (cr:#{n_max[0]})\+#{cr1}[#{cr2}] (cr:計#{n_max.inject(:+)}回)" if (cr1 > 0)
        
        if(treat_flg == true)
          #TREAT追加処理
          heal = rollDiceCommand("TREAT#{total_n}")
          text += "\n ＞ #{heal}"
        end
        
        return text

      when /H/i
        return '' unless( /^H(.*)/i =~ command )
        command = $1
        
        if(command =~ /^([\+\-]?\d+[D\+\-\d+]*)+/i)
          dice_mod = []
          dice_mod_text = []
          $1.scan(/([\+\-]?\d+D6|[\+\-]?\d+)/i) { |match| dice_mod << match }
          dice_mod.flatten!
          
          dice_n = []
          diceText = []
          #cf非適用一投目
          dice_mod.each_with_index{|num, idx|
            if(num =~ /([\+\-])?(\d+)D6/i)
              dice_n[idx], diceText[idx], = roll($2, 6)
              dice_mod[idx] = "#{$1}#{dice_n[idx]}"
              dice_mod_text[idx] = "#{$1}#{dice_n[idx]}[#{diceText[idx]}]"
            else
              dice_mod_text[idx] = dice_mod[idx]
            end
            }
          #nilを0に変換
          dice_n.map!(&:to_i)
          
          #修正値&一投目出目
          total_n = parren_killer("(0#{dice_mod.join})").to_i/2
          #最終達成値
          result = "計【 #{total_n} 】"

          text = "(#{command}) ＞ #{result} ： #{dice_mod_text.join(" ")}"
        
          return text
        
        else
          return rollDiceCommand(command)
        end
        
      when /RA/i
        return '' unless( /^RA(\d+)?$/i =~ command )
        case $1.to_i
          when 50, 70, 90
            text = send("get_ra#{$1.to_i}_table")
          when 110, 120, 130, 140
            text = get_ra100_table
          else
            text = "指定の暴走率の暴走ロールはありません"
        end
        text = "このコマンドは数値を付けてください" if($1.nil? == true)
        return "(#{command}) ＞ #{text}"

      when /SO/i
        return '' unless( /^SO(\d+)?$/i =~ command )
        if ($1.to_i < 1 || $1.to_i > 5 || $1.nil? == true)
          return "(スペックオーバー判定) このコマンドは1~5の数値を付けてください"
        end
        return send("get_so#{$1.to_i}_table", command)

      when 'DOWN'
        guki, = roll(1, 6)
        if(guki % 2 == 0)
          result = "回避"
        else
          result = "気絶"
          fell, = roll(1, 6)
          result += "【#{fell}R行動不能】"
        end
        return "気絶判定 ＞ [#{guki}] #{result}"

      when 'COND'
        hp1, hp2, = roll(2, 6)
        pp1, pp2, = roll(2, 6)
        return "(#{command}) ＞ HP#{hp1}[#{hp2}] 、 PP#{pp1}[#{pp2}]"

      when /CO(NT)?/i
        num, = roll(1, 6)
        case num
          when 1..4
            text = "1R追加"
          when 5, 6
            text = "2R追加"
        end
        return "コンティニュー判定 ＞ [#{num}] #{text}"

      when 'RISK'
        text, num = get_risk_table
        return "(#{command}) ＞ [#{num}] #{text}"

      when 'GUKI'
        guki, = roll(1, 6)
        result = (guki % 2 == 0 ? "成功" : "失敗")
        return "(#{command}) ＞ [#{guki}] ＞ #{result}"

      when /TREAT/i
        return '' unless( /^TREAT(\-?\d+)?$/i =~ command )
        
        h, h1, h2, h3 = 0, 0, 0, 0
        text = "ＡＥ【応急処置】 ＞ "
        
        return "#{text}このコマンドは数値を付けてください" if($1.nil? == true)
        
        case $1.to_i
          when 6, 7
            h, h3 = 1, 1
            text += "HPが#{h}(#{h1}[#{h2}]+#{h3})回復"
          when 8..11
            h1, h2, = roll(1, 6)
            h1 = h1 / 2
            h = h1 + h3
            text += "HPが#{h}(#{h1}[#{h2}]+#{h3})回復"
          when 12..14
            h1, h2, = roll(1, 6)
            h = h1 + h3
            text += "HPが#{h}(#{h1}[#{h2}]+#{h3})回復"
          when 15..17
            h1, h2, = roll(1, 6)
            h3 = 3
            h = h1 + h3
            text += "HPが#{h}(#{h1}[#{h2}]+#{h3})回復"
          when 18..9999
            h1, h2, = roll(2, 6)
            h3 = 2
            h = h1 + h3
            text += "HPが#{h}(#{h1}[#{h2}]+#{h3})回復"
          else
            text += "その値には対応していません"
        end
        return text

      when 'ALLR'
        num, = roll(1, 6)
        case num
          when 1
            text = "発動失敗【技対象が敵味方含めた全員となる】"
          else
            text = "発動成功"
        end
        return "オールレンジ判定 ＞ [#{num}] #{text}"

      when 'PAFE'
        num, = roll(1, 6)
        case num
          when 1
            text = "発動失敗【通常命中・回避判定となり、発動時のアクション内の命中力＆回避力が半減する】"
          else
            text = "発動成功"
        end
        return "発動ロール ＞ [#{num}] #{text}"

      when /FATAL/i
        return '' unless( /^FATAL(\d)?$/i =~ command )
        
        unless ($1.to_i == 1 || $1.to_i == 2)
          return "このコマンドは1か2を付けてください"
        end
        return "このコマンドは1か2を付けてください" if($1.nil? == true)
        
        return send("get_fa#{$1.to_i}_table")

      when 'STAG'
        text, num, = get_stag_table
        num = num.split("")
        return "(#{command}) ＞ [#{num[0]}-#{num[1]}] #{text}"
      
      when 'MIKUZI'
        return get_mikuzi_table
      
      when 'LL'
        num, = roll(1, 6)
        case num
          when 1,3,5
            text, num = get_LL_table
            return "(#{command}) ＞奇数[#{num}] #{text}"
          when 2,4,6
            text, num = get_LL2_table
            return "(#{command}) ＞偶数[#{num}] #{text}"
        end
      when 'ST'
        num, = roll(1, 6)
        case num
          when 1,2
            text, num = get_ST_a_table
            return "(#{command}) ＞A[#{num}] #{text}"
          when 3,4
            text, num = get_ST_b_table
            return "(#{command}) ＞B[#{num}] #{text}"
          when 5,6
            text, num = get_ST_c_table
            return "(#{command}) ＞C[#{num}] #{text}"
        end
    end
  end
  
  
  def get_ra50_table()
    table=[
      '発作【自爆÷2ダメージ。（自身に能力攻撃ロールダメージ÷2）。防御無視】',
      '高揚【1D6暴走率上昇】',
      '高揚【1D6暴走率上昇】',
      '自制【暴走なし】',
      '自制【暴走なし】',
      '自制【暴走なし】'
    ]
    text, num = get_table_by_1d6(table)
   
    case num
      when 2,3
        b1, b2, = roll(1, 6)
        text +=  " ： #{b1}[#{b2}] ％"
    end
    return "[#{num}] #{text}"
  end
  
  def get_ra70_table()
    table = [
      '自爆【自爆ダメージ。自身に能力攻撃ロールダメージ。防御無視】',
      '自爆【自爆ダメージ。自身に能力攻撃ロールダメージ。防御無視】',
      '暴発【ランダム攻撃。基本的に能力攻撃。対象は自分、キャラ、オブジェクトの三種類】',
      '連鎖【2D6暴走率上昇】',
      '発症',
      '自制【暴走無し】'
    ]
    text, num = get_table_by_1d6(table)
    
    case num
      when 4
        b1, b2, = roll(2, 6)
        text += " ： #{b1}[#{b2}] ％"
      when 5
        text += " ： #{get_ra90_table}"
    end
    return "[#{num}] #{text}"
  end
  
  def get_ra90_table()
    guki, = roll(1,6)
    
    if (guki % 2 == 0)
      table = [
        '制御異常【自プリアクション毎（行動決定前）に偶奇判定。奇数の場合は暴発によるランダム攻撃。（発症時も発生）。技術、幸運の判定結果が半減】',
        '過負荷【ワンアクション毎に能力精度÷3の防御無視ダメージ（発症時も発生）。閃きの判定結果が半減】',
        '聴覚異常【回避判定結果が半減する。察知の半減結果が半減】',
        '視覚異常【SS＆命中力＆回避力が半減する※判定結果は半減しない。観察眼の判定結果が半減】',
        '身体異常【防御を差し引く前のダメージロールが半減する。力技、俊敏の判定結果が半減】',
        '自制【暴走なし】'
      ]
      text, num = get_table_by_1d6(table)
    else
      table = [
        '能力異常【能力使用時に偶奇判定。奇数の場合は消費だけ行い能力発動失敗。暴走チェックごとに+2％される（発症時も発生）。能力精度の判定結果が半減】',
        '言語異常【AE使用時に偶奇判定。奇数の場合は消費だけ行いAE発動失敗。話術の判定結果が半減】',
        '記憶異常【命中判定結果が半減する。知識の判定結果が半減】',
        '精神異常【自分のリアクション（回避判定など）で偶奇判定。奇数の場合は行動自動失敗。隠密、読心の判定結果が半減】',
        '忘我【自プリアクション時に偶奇判定。奇数の場合は宣言せずにターン終了。あらゆる技能判定結果が半減】',
        '自制【暴走無し】'
      ] 
      text, num = get_table_by_1d6(table)
    end
    
    return "[#{guki}-#{num}] #{text}"
  end
  
  def get_ra100_table()
    table=[
      '自壊【自爆ダメージ。自身の最も高い攻撃ロールダメージ。防御無視】',
      '超活性【HP・PPを2D6回復】',
      '自壊【自爆ダメージ。自身の最も高い攻撃ロールダメージ。防御無視】',
      '超活性【HP・PPを2D6回復】',
      '自壊【自爆ダメージ。自身の最も高い攻撃ロールダメージ。防御無視】',
      '超活性【HP・PPを2D6回復】'
    ]
    text, num = get_table_by_1d6(table)
   
    if(num % 2 == 0)
      b1, b2, = roll(2, 6)
      text +=  " ： #{b1}[#{b2}] 回復"
    end
   
    return "[#{num}] #{text}"
  end
  
  def get_so1_table(command)
    table = [
      '消費負荷【ＰＰ２倍消費　※ＡＥ消費は含まない】',
      '消費負荷【ＰＰ２倍消費　※ＡＥ消費は含まない】',
      '消費負荷【ＰＰ２倍消費　※ＡＥ消費は含まない】',
      '反動',
      '反動',
      '制御成功【発動成功　ペナルティ無し】'
    ]
    text, num = get_table_by_1d6(table)
    
    case num
      when 4, 5
        b1, b2, = roll(1, 6)
        text +=  "【命中＆回避－１Ｄ６（#{b1}[#{b2}]）　１ラウンド継続】"
    end
   
   return "(#{command}) ＞ [#{num}] #{text}"
  end
  
  def get_so2_table(command)
    table = [
      '自爆【自分へ能力攻撃ダメージ　※防御無視】',
      '消費負荷【ＰＰ２倍消費　※ＡＥ消費は含まない】',
      '消費負荷【ＰＰ２倍消費　※ＡＥ消費は含まない】',
      '反動',
      '反動',
      '制御成功【発動成功　ペナルティ無し】'
    ]
    text, num = get_table_by_1d6(table)
    
    case num
      when 4, 5
        b1, b2, = roll(1, 6)
        text +=  "【命中＆回避－１Ｄ６（#{b1}[#{b2}]）　１ラウンド継続】"
    end
    
   return "(#{command}) ＞ [#{num}] #{text}"
  end
  
  def get_so3_table(command)
    table = [
      '自爆【自分へ能力攻撃ダメージ　※防御無視】',
      '自爆【自分へ能力攻撃ダメージ　※防御無視】',
      '消費負荷【ＰＰ２倍消費　※ＡＥ消費は含まない】',
      '過反動',
      '過反動',
      '制御成功【発動成功　ペナルティ無し】'
    ]
    text, num = get_table_by_1d6(table)
    
    case num
      when 4, 5
        b1, b2, = roll(2, 6)
        text +=  "【命中＆回避－２Ｄ６（#{b1}[#{b2}]）　１ラウンド継続】"
    end
    
   return "(#{command}) ＞ [#{num}] #{text}"
  end
  
  def get_so4_table(command)
    table = [
      '崩壊【自爆ダメージ×２　※防御無視】',
      '崩壊【自爆ダメージ×２　※防御無視】',
      '超負荷【ＰＰ３倍消費　※ＡＥ消費は含まない】',
      '過反動',
      '過反動',
      '制御成功【発動成功　ペナルティ無し】'
    ]
    text, num = get_table_by_1d6(table)
    
    case num
      when 4, 5
        b1, b2, = roll(2, 6)
        text +=  "【命中＆回避－２Ｄ６（#{b1}[#{b2}]）　１ラウンド継続】"
    end
    
   return "(#{command}) ＞ [#{num}] #{text}"
  end
  
  def get_so5_table(command)
    table = [
      '崩壊【自爆ダメージ×２　※防御無視】',
      '崩壊【自爆ダメージ×２　※防御無視】',
      '崩壊【自爆ダメージ×２　※防御無視】',
      '超負荷【ＰＰ３倍消費　※ＡＥ消費は含まない】',
      '超負荷【ＰＰ３倍消費　※ＡＥ消費は含まない】',
      '制御成功【発動成功　ペナルティ無し】'
    ]
    text, num = get_table_by_1d6(table)
   
   return "(#{command}) ＞ [#{num}] #{text}"
  end
  
  def get_risk_table()
    table = [
      '能力自爆【能力は発動せず、ＰＰを２倍消費する。併用ＡＥのＰＰは含まない。それに加え【自爆】する。能力攻撃力分を自身へ防御無視ダメージ】',
      '能力不発【能力は発動せず、ＰＰを２倍消費する。併用ＡＥのＰＰは含まない】',
      '効果不発【リスクの効果はゼロで能力発動】',
      '通常発動【（能力精度÷３）＋１Ｄ６を加える】',
      '活性発動【（能力精度÷３）＋２Ｄ６を加える】',
      '覚醒発動【（能力精度÷３）＋３Ｄ６を加える】'
    ]
   return get_table_by_1d6(table)
  end
  
  def get_fa1_table()
    table = [
      '能力変化【能力がまったく別ものに変化する】',
      '能力変化【能力がまったく別ものに変化する】',
      '因子抑制【能力変化は起こらない】 ',
      '因子抑制【能力変化は起こらない】 ',
      '能力喪失・能力覚醒【能力を持つものは失い、ノーマルは能力に覚醒する。喪失者はノーマルのキャラ特性ポイントを1p獲得する。覚醒者はノーマルのキャラ特性ポイントを1p失い、キャラ特性を6つ取得していた場合は1つ喪失する】',
      '能力喪失・能力覚醒【能力を持つものは失い、ノーマルは能力に覚醒する。喪失者はノーマルのキャラ特性ポイントを1p獲得する。覚醒者はノーマルのキャラ特性ポイントを1p失い、キャラ特性を6つ取得していた場合は1つ喪失する】'
    ]
    text, num = get_table_by_1d6(table)
   
    case num
      when 1, 2, 5, 6
        psy = get_psy_table
    end
   
   return "因子変化判定 ＞ [#{num}] #{text} #{psy}"
  end
  
  def get_fa2_table()
    table = [
      '聴覚崩壊【聴覚に異常が起きる。幻聴、難聴、失聴、など】',
      '視覚崩壊【視覚に異常が起こる。幻覚、色盲、失明、など】',
      '言語崩壊【言語の認識に異常が起きる。しゃべる事に支障をきたす。吃音、失語症、失読症、など】',
      '身体崩壊【身体に異常が起こる。欠損、異形化、麻痺、など】',
      '精神崩壊【精神に異常が起こる。人格破綻、性格変化、妄想・幻覚による異常行動、など】',
      '記憶崩壊【記憶に異常が起こる。記憶障害、記憶喪失、など】'
    ]
    text, num = get_table_by_1d6(table)
   
   return "後遺症判定 ＞ [#{num}] #{text}"
  end
  
  def get_psy_table()
    table = [
      'サイキッカー',
      'エスパー',
      'トランサー',
      'クリエイター',
      'アンノウン',
      '好きな能力タイプを選択。ノーマル選択でも可'
    ]
    text, num = get_table_by_1d6(table)
   
   return "[#{num}] #{text}"
  end
  
  def get_stag_table()
    table = [
      'ロシアンルーレット【幸運にて判定。参加者は銃をこめかみにあて、１発の銃弾をひかないように祈る。 敗者は３Ｄ６ダメージ】',
      'チキンレース【察知にて判定。に向ってバイクでダッシュだ。敗者は２Ｄ６ダメージ。落ちても大丈夫です、電脳だから】',
      '取り立て【力技or威圧にて判定。あのモヒカン借金払わないんですよ。よろしくお願いしますね。電脳を通しての実際の取り立てらしい】',
      '舌戦【威圧or話術にて判定。参加者同士で舌戦で勝者を決めろ！敗者は心に２Ｄ６ダメージ】',
      'ギャンブル【読心or幸運にて判定。ポーカー、ルーレット、麻雀、好きなものを選べ。勝利の鍵は運か、それとも人の心か】',
      'トラップ【ＳＳにて判定。君達の目の前に広がるのはそう、地雷原だ。敗者は３Ｄ６ダメージ】',

      'サバゲー【隠密or俊敏にて判定。軍人となって、相手を屠れ！敗者は死ぬ。敗者は２Ｄ６ダメージ】',
      '追跡【察知or隠密にて判定。ニンジャの姿となって下手人を追え！コアな人気を誇るステージ。ニンジャ人気すごい】',
      '推理【閃きにて判定。あなたたちは探偵となり、事件を解決に導く。犯人は、お前だ！２時間放送になるのが玉に瑕】',
      '潜入【隠密にて判定。スパイとなり、機密情報を盗め！あれ、これ実際の企業の機密情報じゃ・・・？】',
      'かくれんぼ【隠密or読心にて判定。あなたを追うのはホラーな化け物・・・。スリリングなかくれんぼをどうぞ堪能下さい】',
      '絶対絶命！【回避力にて判定。君達はマフィアにおびき出されたのだ。大勢の銃が君を狙う。敗者は３Ｄ６ダメージ】',

      'クイズ【知識にて判定。己の知識を存分に披露しろ！負けたら奈落に落されます。敗者は１Ｄ６ダメージ】',
      '迷路【察知or幸運にて判定。巨大迷路をクリアしろ！あれ、なんでこんなところに骸骨が・・・】',
      'パズル【知識or閃きにて判定。３Ｄの難解パズルを解き明かせ！！時折金庫破りのパスワードがターゲットになってたり】',
      '間違い探し【観察眼or閃きにて判定。大量の鍵から正しい鍵を。美女の中からオカマを。そんな間違いを見つけるのだ！】',
      '目利き【観察眼or知識にて判定。あなたの鑑定で値段を当てろ！はずれたらかっこ悪いです】',
      'スナイパー【命中力にて判定。一撃必殺でターゲットを仕留めろ！なお、ターゲットはお互いだ。敗者は２Ｄ６ダメージ】',

      '腕相撲【力技にて判定。必要なのは、力のみ！！敗者は２Ｄ６ダメージ】',
      'インディジョーンズ【俊敏にて判定。なぜか大岩が後ろから！逃げろー！敗者は３Ｄ６ダメージ】',
      'ＰＫ【力技or察知にて判定。見極め、ゴールしろ！パワーで破ってもいい】',
      'ダンス【技術or俊敏にて判定。己の舞を魅せろ！ジャンル問わず】',
      'ボディコンテスト【威圧にて判定。魅せるのはマッスルか、それとも美しい肢体か！容姿ボーナスはつきません】',
      '突破しろ！【ダメージ量にて判定。立ちはだかる扉をぶち破れ！扉は防御１０】',

      '早食い【力技or俊敏にて判定。くって！くって！！くいまくれ！！敗者は胃に２Ｄ６ダメージ】',
      'ナンパ天国【話術or読心にて判定。電脳世界で老若男女を口説き落せ！相手はプログラムだったり電脳に入っているアバターだったり】',
      'スリーサイズ【観察眼にて判定。魅惑のボディをなめまわせ！勝利者はある意味で尊敬され、ある意味で嫌われる】',
      'ワサビ寿司【観察眼or幸運にて判定。高級寿司の中に、死ぬほどの刺激が・・・！敗者は２Ｄ６ダメージ】',
      'じゃんけん【読心にて判定。じゃんけんとは運ではない、読み合いなのだ！】',
      '瓦割り【ダメージ量にて判定。どんな方法でもいい。とにかく枚数を割れ！！！ダメージ量の２倍くらいが割った枚数】',

      '料理対決【知識or技術にて判定。胃袋をつかめ！絶品料理対決！料理によってはＲ１８Ｇ指定になる場合がある】',
      '歌合戦【威圧or技術にて判定。その歌唱力で心をつかめ！アイドルデビューも夢じゃない！電脳なのでお好きな衣装でどうぞ】',
      '漫才【話術or閃きにて判定。即興漫才で画面の向こうを爆笑の渦へ！相方が必要な方は漫才プログラムアバターをレンタル。有料】',
      '画伯【技術にて判定。テーマをもとに、あなたの画力を見せつけろ！時々下手うまな人が勝つことも】',
      'プレゼンテーション【話術にて判定。本日の商品は、こちら！！実際に販売します。してもらいます】',
      '無双撃破！【ダメージ量にて判定。た、大量のモヒカンだぁ～！ダメージ量の２倍くらいが倒した数。敗者は２Ｄ６ダメージ。ＳＥ【オールレンジ】技は成功で判定＋１０】'
    ]
    return get_table_by_d66(table)
  end
  
  def get_mikuzi_table()
    table = [
      "疲れてませんか？憑かれてませんか？\n何度も続くようならお祓いに行った方がいいかもしれません。\n出目事故は起こるものと心得ましょう。",
      "ここぞという場面でこそ他のPLに託し、ダイスを振らないのも手です。\n一見してPTの平均出目を下げているようでも漏れなく味方に\n運を提供している……はず。",
      "突出して悪くはありませんが、気を抜いてませんか？\n心を清らかにして女神様に祈ってみましょう。\n効果は女神様の気分次第。",
      "悪いと言い切れるほどではありません。\nだからこそ、不測の事態に心の備えをしましょう。\n備えが役に立つかは不明。",
      "どちらかと言えば好調と言えるでしょう。\nここからの転落事故に要注意。\n某70では最悪の引きにもなり得ます。",
      "おめでとうございます、貴方はツイているでしょう。\nこれからもこの引きを維持しましょう。\n常に６を手元に置けば何も怖くない。"
    ]
    text, num = get_table_by_1d6(table)
   
    return "ネタみくじ【#{num}】 \n#{text}"
  end
  
  def get_LL_table()
    table = [
        '異形',
        '恩恵',
        '暴走',
        '才能',
        '実験',
        '崩壊',

        '喪失',
        '復讐',
        '逃亡',
        '傷病',
        '贖罪',
        '裏切り',

        '名声',
        '悪名',
        '孤独',
        '義理の家族',
        '機械化',
        '被害者',

        '成功',
        '没落',
        '権力',
        '勤労',
        '無名',
        '裏社会',

        '平凡',
        '商人',
        '犯罪',
        '技術者',
        '宗教',
        '芸術',

        '忠誠',
        '野心',
        '秘密',
        '探究',
        '武道',
        '研究'
    ]
    return get_table_by_d66(table)
  end
  

  def get_LL2_table()
    table = [
#【交流】
        '恋愛',
        '友人',
        '師匠',
        '尊敬',
        '疎遠',
        '邂逅',
#【経済】
        '裕福',
        '貧乏',
        '兵士',
        '略奪',
        '成金',
        '放浪',
#【生命】
        '短命',
        '親子',
        '救済',
        '殺人',
        '自殺',
        '臨死',
#【世間】
        '実現',
        '再生',
        '守護',
        '漠然',
        '（未定）',
        '啓蒙',
#【組織】
        '有能',
        '非才',
        '賛美',
        '新参',
        '古参',
        '離反',
#【出自】
        '外界',
        '内界',
        '迫害',
        '無実',
        '幽閉',
        '不明【それまでの来歴を誰も知らない。】'
    ]
    return get_table_by_d66(table)
  end
  
  def get_ST_a_table()
    table = [
        '正義',
        '中庸',
        '悪徳',
        '優柔不断',
        '唯我独尊',
        '天真爛漫',

        '男性的',
        '中性的',
        '女性的',
        '一途',
        '好色',
        '同性愛',

        '豪胆',
        'ポジティブ',
        '自由',
        'お人好し',
        '目立ちたがり',
        '友好',

        '温厚',
        '慈愛',
        '奉仕',
        '平和主義',
        'マイペース',
        '八方美人',

        '単純',
        '自信家',
        '無鉄砲',
        '気分屋',
        '努力家',
        '敏感',

        '常識',
        '愚直',
        '規律',
        '気品',
        '現実主義',
        '誠実【物事に対して正しく接する。】'
    ]
    return get_table_by_d66(table)
  end
  
  def get_ST_b_table()
    table = [
        '家族',
        '友情',
        '愛',
        '仁義',
        '礼節',
        '誇り',

        '倹約',
        '几帳面',
        '独立',
        '物欲',
        'リーダーシップ',
        '慎重',

        '臆病',
        'ネガティブ',
        '寂しがり屋',
        '嫉妬',
        '疑心',
        '虚偽',

        '厳格',
        '頑固',
        '激情',
        '好戦的',
        '反発',
        '騒然',

        '寡黙',
        '一匹狼',
        '冷徹',
        '静観',
        '怠け者',
        '鈍感',

        '偏屈',
        '依存',
        'ズボラ',
        '下賤',
        'ロマンティスト',
        '浪費【お金に無頓着。】'
    ]
    return get_table_by_d66(table)
  end
  

  def get_ST_c_table()
    table = [
        '（未定）',
        '幼稚',
        '不義理',
        '差別的',
        '欠落',
        '憎悪',

        '熱血',
        '好奇心',
        '（未定）',
        '負けず嫌い',
        '（未定）',
        '盲信',

        '（未定）',
        '冷静',
        '皮肉屋',
        '無欲',
        '生意気',
        '他罰的',

        '執着',
        '求道',
        'サディスト',
        'マゾヒスト',
        '無欲',
        '暴食',

        '（未定）',
        '完璧主義',
        '秩序',
        '無法',
        '不安定',
        '自罰的',

        '生存',
        '捨身',
        '大勢順応',
        '謙虚',
        '劣等感',
        'ナルシスト【自分が大好き。】'
    ]
    return get_table_by_d66(table)
  end
  
end
