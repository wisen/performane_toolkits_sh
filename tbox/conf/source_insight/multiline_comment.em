macro MultiLineComment()

{

    hwnd = GetCurrentWnd()

    selection = GetWndSel(hwnd)

    LnFirst =GetWndSelLnFirst(hwnd)      //取首行行号

    LnLast =GetWndSelLnLast(hwnd)      //取末行行号

    hbuf = GetCurrentBuf()

 

    if(GetBufLine(hbuf, 0) =="//magic-number:tph85666031"){

        stop

    }

 

    Ln = Lnfirst

    buf = GetBufLine(hbuf, Ln)

    len = strlen(buf)

 

    while(Ln <= Lnlast) {

        buf = GetBufLine(hbuf, Ln)  //取Ln对应的行

        if(buf ==""){                   //跳过空行

            Ln = Ln + 1

            continue

        }

 

        if(StrMid(buf, 0, 1) == "/"){       //需要取消注释,防止只有单字符的行

            if(StrMid(buf, 1, 2) == "/"){

                PutBufLine(hbuf, Ln, StrMid(buf, 2, Strlen(buf)))

            }

        }

 

        if(StrMid(buf,0,1) !="/"){          //需要添加注释

            PutBufLine(hbuf, Ln, Cat("//", buf))

        }

        Ln = Ln + 1

    }

 

    SetWndSel(hwnd, selection)

} \   E-SafeNet   LOCK            喒M霍\灿蓽	蕭O軒�謳� �該p                                                                                            w�曫t亢Q怞V�蚻蚴}芋x某!矵szPd��薤Z舔孑羐|燐vr笭� 姸.鋁稜遮宦゜GF廛媰|R柒$5\簿D&o\騖肹i�'J@�艼 誟;Pl装7譈�,>䦆尩l匏訌5P闵}门 � 烿憀�	s^v菰怾圸ND|t?gk�A湬c仫��W�2g成騡棓�斅釻駱dY 瑗鞪'偵&1榓瘧J杍s�