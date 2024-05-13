#INCLUDE "PROTHEUS.CH"
//----------------------------------------------------------------------
/*/{PROTHEUS.DOC} WMSQYSEP
Ponto-de-Entrada: Query utilizada na separação dos PVs
@OWNER AgriVale
@VERSION PROTHEUS 12
@SINCE 27/06/23
@ 
/*/
User Function WMSQYSEP()
Local cAliasD14
Local cArmazem   := PARAMIXB[1]
Local cEndereco  := PARAMIXB[2]
Local cProduto   := PARAMIXB[3]
Local cPrdOri    := PARAMIXB[4]
Local cLoteCtl   := PARAMIXB[5]
Local cNumLote   := PARAMIXB[6]
Local lCnsPkgFut := PARAMIXB[7]
Local cOrigem    := DCF->DCF_ORIGEM
Local cServic    := DCF->DCF_SERVIC
Local cDocumento := DCF->DCF_DOCTO
Local cCarga     := DCF->DCF_CARGA
Local cSeq       := DCF->DCF_XSEQ
Local cItemPV    := PADR(DCF->DCF_SERIE, TAMSX3("C6_ITEM")[1])
Local lCross     := Posicione("DC5", 1, xFilial("DC5")+cServic, "DC5_OPERAC") == "4" // CrossDocking
Local cRegra     := DCF->DCF_REGRA
Local cEndCons   := PADR(SuperGetMV('PC_ENDCONS',.F.,"CONS01"), TAMSX3("BE_LOCALIZ")[1]) // Endereço para realizar a separação dos PVs
Local lMatriz    := u_EmpMatr()
Local cAliasSD2
Local lSepZ06    := .T.
PuBlic cAGIDPal  := CriaVar("D14_IDUNIT", .F.)
If !lCross
	If cFilAnt == "010102"
		If cOrigem == "SC9" .and. !Empty(cCarga)
 			cAliasD14 := u_QrySep(lCnsPkgFut, cArmazem, cProduto, cPrdOri, cEndCons, cLoteCtl, cNumLote, cRegra,, cCarga, cSeq, lSepZ06)
		Endif
	ElseIf lMatriz
		cFilDep := Posicione("NNR", 1, xFilial("NNR")+cArmazem, "NNR_XCODFI")
		If !Empty(cFilDep)
			dbSelectArea("SC5")
			dbSetOrder(1)
			If dbSeek(xFilial()+cDocumento)
				cPvDep := SC5->C5_XNUMORI
				If !Empty(cPvDep)
					cAliasSD2 := GetNextAlias()
					BeginSql Alias cAliasSD2
					SELECT
						D2_COD, D2_QUANT, D2_LOTECTL
					FROM
						%table:SD2% SD2
					WHERE
						SD2.D2_FILIAL = %Exp:cFilDep%
						AND SD2.D2_PEDIDO = %Exp:cPvDep%
						AND SD2.D2_ITEMPV = %Exp:cItemPV%
						AND SD2.D2_COD = %Exp:cProduto%
						AND SD2.%NotDel% 
					EndSql
					If (cAliasSD2)->(!Eof())
						lSepZ06    := .F.
						nQtdDep := (cAliasSD2)->D2_QUANT
						cLoteDep := (cAliasSD2)->D2_LOTECTL
						cAliasD14 := u_QrySep(lCnsPkgFut, cArmazem, cProduto, cPrdOri, cEndereco, cLoteDep, cNumLote, cRegra,, cCarga, cSeq, lSepZ06)
					Endif
					(cAliasSD2)->(dbCloseArea())
				Endif
			Endif
		Endif
	Endif
Endif
Return cAliasD14
//------------------------------------------------------------------------------------------------------------------------------------------------
User Function QrySep(lCnsPkgFut, cArmazem, cProduto, cPrdOri, cEndCons, cLoteCtl, cNumLote, cRegra, cNoEnd, cCarga, cSeq, lSepZ06, lProd)

Local aTamSX3    := TamSx3("D14_QTDEST")
Local cQuery     := ""
Local oFuncao    := Nil
Local cAliasD14  := GetNextAlias()
Default cNoEnd   := CriaVar("BE_LOCALIZ", .F.)
Default cEndCons := CriaVar("BE_LOCALIZ", .F.)
Default cCarga   := CriaVar("DCF_CARGA", .F.)
Default cSeq     := CriaVar("DCF_XSEQ", .F.)
Default lSepZ06  := .F.
Default lProd    := .F.
oFuncao := WMSBCCSeparacao():New()
oFuncao:oMovEndOri:SetArmazem(cArmazem)
oFuncao:oMovPrdLot:SetProduto(cProduto)
oFuncao:oMovPrdLot:SetPrdOri(cPrdOri)
oFuncao:oMovEndOri:SetEnder(cEndCons)
oFuncao:oMovPrdLot:SetLoteCtl(cLoteCtl)
oFuncao:oMovPrdLot:SetNumLote(cNumLote)
oFuncao:oOrdServ:SetRegra(cRegra)
cQuery :=              "% CASE DC8.DC8_TPESTR"
If oFuncao:oMovServic:ChkSepNorm() // Separação com ou sem volume
	cQuery +=           " WHEN '4' THEN 1" 
	cQuery +=           " WHEN '6' THEN 2" 
	cQuery +=           " WHEN '1' THEN 3" 
	cQuery +=           " WHEN '2' THEN 4" 
	cQuery +=           " WHEN '3' THEN 5 END DC3_REGRA,"
Else // Separaçao cross docking com e sem volume
	cQuery +=           " WHEN '3' THEN 1" 
	cQuery +=           " WHEN '6' THEN 2" 
	cQuery +=           " WHEN '4' THEN 3" 
	cQuery +=           " WHEN '1' THEN 4" 
	cQuery +=           " WHEN '2' THEN 5 END DC3_REGRA,"
EndIf
cQuery +=           " CASE DC3.DC3_UMMOV"
cQuery +=               " WHEN '1' THEN 2" 
cQuery +=               " WHEN '2' THEN 1" 
cQuery +=               " WHEN '3' THEN 3"
cQuery +=               " ELSE 2 END DC3_UMMOV,"
cQuery +=           " DC3_ORDEM,"
cQuery +=           " DC3_QTDUNI,"
cQuery +=           " D14_ENDER,"
cQuery +=           " D14_ESTFIS,"
cQuery +=           " D14_LOTECT,"
cQuery +=           " D14_NUMLOT,"
cQuery +=           " D14_DTVALD,"
cQuery +=           " D14_NUMSER,"
cQuery +=           " D14_PRIOR,"
If lCnsPkgFut
	cQuery +=       " ((D14_QTDEST+D14_QTDEPR)-(D14_QTDEMP+D14_QTDBLQ)) D14_QTDLIB,"
	cQuery +=       " ((D14_QTDEST+D14_QTDEPR)-(D14_QTDEMP+D14_QTDBLQ+D14_QTDSPR)) D14_SALDO,"
Else
	cQuery +=       " (D14_QTDEST-(D14_QTDEMP+D14_QTDBLQ)) D14_QTDLIB,"
	cQuery +=       " (D14_QTDEST-(D14_QTDEMP+D14_QTDBLQ+D14_QTDSPR)) D14_SALDO,"
EndIf
cQuery +=           " D14_QTDSPR,"
cQuery +=           " D14_QTDPEM,"
cQuery +=           " D14_IDUNIT,"
cQuery +=           " D14_CODUNI,"
cQuery +=           " BE_STATUS,"
If !lCnsPkgFut
	cQuery +=       " CASE WHEN DC8.DC8_TPESTR "+Iif(!oFuncao:lFefoBlFr,"IN ('4','6')","= '4'")+" THEN ((BE_VALNV1+BE_VALNV2+BE_VALNV3+BE_VALNV4)*"+Iif(oFuncao:lBlOrdDec,"(-1)","1")+") ELSE 0 END SBE_ORDCOR"
Else
	cQuery +=       " 0 SBE_ORDCOR"
EndIf
If lSepZ06
	cQuery +=  " FROM "+RetSqlName("Z06")+" Z06, " + RetSqlName("D14")+" D14"
Else
	cQuery +=  " FROM "+RetSqlName("D14")+" D14"
Endif
// Quando separa por data de validade não segue a sequencia de abastecimento
cQuery +=     " INNER JOIN "+RetSqlName("DC3")+" DC3"
cQuery +=        " ON DC3.DC3_FILIAL = '"+xFilial("DC3")+"'"
cQuery +=       " AND DC3.DC3_LOCAL  = D14.D14_LOCAL"
cQuery +=       " AND DC3.DC3_CODPRO = D14.D14_PRODUT"
cQuery +=       " AND DC3.DC3_TPESTR = D14.D14_ESTFIS"
cQuery +=       " AND DC3.D_E_L_E_T_ = ' '"
cQuery +=     " INNER JOIN "+RetSqlName("DC8")+" DC8"
cQuery +=        " ON DC8.DC8_FILIAL = '"+xFilial("DC8")+"'"
cQuery +=       " AND DC8.DC8_CODEST = D14.D14_ESTFIS"
cQuery +=       " AND DC8.D_E_L_E_T_ = ' '"
cQuery +=     " INNER JOIN "+RetSqlName("SBE")+" SBE"
cQuery +=        " ON SBE.BE_FILIAL  = '"+xFilial("SBE")+"'"
cQuery +=       " AND SBE.BE_LOCAL   = D14.D14_LOCAL"
cQuery +=       " AND SBE.BE_LOCALIZ = D14.D14_ENDER"
cQuery +=       " AND SBE.BE_ESTFIS  = D14.D14_ESTFIS"
cQuery +=       " AND SBE.D_E_L_E_T_ = ' '"
cQuery +=     " WHERE D14.D14_FILIAL = '"+xFilial("D14")+"'"
cQuery +=       " AND D14.D14_LOCAL  = '"+oFuncao:oMovEndOri:GetArmazem()+"'"
cQuery +=       " AND D14.D14_PRODUT = '"+oFuncao:oMovPrdLot:GetProduto()+"'"
cQuery +=       " AND D14.D14_PRDORI = '"+oFuncao:oMovPrdLot:GetPrdOri()+"'"
If !Empty(oFuncao:oMovEndOri:GetEnder())
	cQuery +=   " AND D14.D14_ENDER = '"+oFuncao:oMovEndOri:GetEnder()+"'"
EndIf
If !Empty(oFuncao:oMovPrdLot:GetLoteCtl())
	cQuery +=   " AND D14.D14_LOTECT = '"+oFuncao:oMovPrdLot:GetLoteCtl()+"'"
EndIf
If !Empty(oFuncao:oMovPrdLot:GetNumLote())
	cQuery +=   " AND D14.D14_NUMLOT = '"+oFuncao:oMovPrdLot:GetNumLote()+"'"
EndIf
If !Empty(cNoEnd)
	cQuery +=   " AND D14.D14_ENDER <> '"+cNoEnd+"'"
EndIf
If lCnsPkgFut
	cQuery +=   " AND DC8.DC8_TPESTR = '2'"
	cQuery +=   " AND ((D14.D14_QTDEST+D14.D14_QTDEPR)-(D14.D14_QTDEMP+D14.D14_QTDBLQ)) > 0"
Else
	If lProd
		cQuery +=   " AND DC8.DC8_TPESTR = '7'"
	Else
		cQuery +=   " AND DC8.DC8_TPESTR IN ('1','2','3','4','6')"
	Endif
	cQuery +=   " AND (D14.D14_QTDEST-(D14.D14_QTDEMP+D14.D14_QTDBLQ)) > 0"
EndIf
If lSepZ06
	cQuery +=   " AND Z06.Z06_FILIAL = '"+xFilial("Z06")+"'"
	cQuery +=   " AND Z06.Z06_CARGA = '" + cCarga + "'"
	cQuery +=   " AND Z06.Z06_SEQ = '" + cSeq + "'"
	cQuery +=   " AND Z06.Z06_PRODUT = D14.D14_PRODUT"
	cQuery +=   " AND Z06.Z06_LOTECT = D14.D14_LOTECT"
	cQuery +=   " AND Z06.Z06_LOCAL = D14.D14_LOCAL"
	cQuery +=   " AND Z06.Z06_ENDER = D14.D14_ENDER"
	cQuery +=   " AND Z06.D_E_L_E_T_ = ' '"
Endif
// // somente se não for regra de data de validade, senão apenas busca o produto mais antigo
If oFuncao:oOrdServ:GetRegra() <> "4"
	cQuery +=   " AND (DC8.DC8_TPESTR <> '3' OR"
	cQuery +=        " NOT EXISTS(SELECT 1 FROM "+RetSqlName("D10")+" D10"
	cQuery +=                    " WHERE D10.D10_FILIAL = '"+xFilial("D10")+"'"
	cQuery +=                     " AND (D10.D10_CLIENT <> '"+oFuncao:oOrdServ:GetCliFor()+"' "
	cQuery +=                          " OR D10.D10_LOJA <> '"+oFuncao:oOrdServ:GetLoja()+"')"
	cQuery +=                          " AND D10.D10_LOCAL = '"+oFuncao:oMovEndOri:GetArmazem()+"'"
	cQuery +=                          " AND D10.D10_ENDER = D14.D14_ENDER"
	cQuery +=                          " AND D10.D_E_L_E_T_ = ' ' ))"
EndIf
cQuery +=       " AND D14.D_E_L_E_T_ = ' '"
If oFuncao:oOrdServ:GetRegra() == "4"
	// Ordenar consulta -> Dt.Validade Lote + Prioridade + Endereco
	cQuery += " ORDER BY "
	cQuery +=          " DC3_ORDEM,"
	cQuery +=          " DC3_QTDUNI DESC,"
	cQuery +=          " DC3_UMMOV,"
	cQuery +=          " D14_PRIOR,"
	cQuery +=          " D14_IDUNIT,"
	cQuery +=          " D14_ENDER"
ElseIf oFuncao:oOrdServ:GetRegra() == "1"
	// Ordenar consulta -> Prioridade + Lote + Sub-Lote + Endereco
	cQuery += " ORDER BY DC3_REGRA,"
	cQuery +=          " DC3_QTDUNI DESC,"
	cQuery +=          " DC3_UMMOV,"
	cQuery +=          " DC3_ORDEM,"
	cQuery +=          " D14_PRIOR,"
	cQuery +=          " SBE_ORDCOR,"
	cQuery +=          " D14_LOTECT,"
	cQuery +=          " D14_NUMLOT,"
	cQuery +=          " D14_IDUNIT,"
	cQuery +=          " D14_ENDER"
Else // Data (Default)
	cQuery += " ORDER BY DC3_REGRA,"
	cQuery +=          " DC3_QTDUNI DESC,"
	cQuery +=          " DC3_UMMOV,"
	cQuery +=          " DC3_ORDEM,"
	cQuery +=          " D14_PRIOR,"
	cQuery +=          " SBE_ORDCOR,"
	cQuery +=          " D14_DTVALD,"
	cQuery +=          " D14_LOTECT,"
	cQuery +=          " D14_NUMLOT,"
	cQuery +=          " D14_IDUNIT,"
	cQuery +=          " D14_ENDER"
EndIf
cQuery += "%"
BeginSql Alias cAliasD14
	SELECT %Exp:cQuery%
EndSql
// Ajustando o tamanho dos campos da query
TcSetField(cAliasD14,'D14_DTVALD','D')
TcSetField(cAliasD14,'D14_QTDLIB','N',aTamSX3[1],aTamSX3[2])
TcSetField(cAliasD14,'D14_QTDSPR','N',aTamSX3[1],aTamSX3[2])
TcSetField(cAliasD14,'D14_QTDPEM','N',aTamSX3[1],aTamSX3[2])
TcSetField(cAliasD14,'D14_SALDO','N',aTamSX3[1],aTamSX3[2])
Return cAliasD14
