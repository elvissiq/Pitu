#Include "PROTHEUS.ch"

//------------------------------------------------------------
/*/ Rotina MATA681

  Ponto de entrada MT681INC
    
   É executado após a gravação dos dados na rotina de inclusão
   do apontamento de produção PCP Mod2.

   Implementado para:
      - Gerar unitizador de acordo com o campo 'H6_XPALETE'.

  @author Anderson Almeida - TOTVS
  @since   02/09/2024 - Desenvolvimento da Rotina.
/*/
//------------------------------------------------------------- 
User Function MT681INC()
  Local aArea       := FWGetArea()
  Local lRet        := .T.
  Local cOrigem     := "SC2"
  Local cEndereco   := SuperGetMV("MV_XENDPAD",.F.,"DOCAE")
  Local cTipoUnit   := SuperGetMV("MV_XWMSUNI",.F.,"000001")
  Local cEndDest    := SuperGetMV("MV_XENDDES",.F.,"PRODUCAO")
  Local cIdUnitiz	:= IIf(SH6->(FieldPos("H6_XPALETE")) > 0,;
                        IIf(! Empty(AllTrim(SH6->H6_XPALETE)),;
						    WmsGerUnit(.F.,.F.,.F., AllTrim(SH6->H6_XPALETE),cTipoUnit),;
							WmsGerUnit(.F.,.T.)), WmsGerUnit(.F.,.T.))
  Local oMntUniItem := WMSDTCMontagemUnitizadorItens():New()
  
  Private cDocumento := ""

 // -- Criar / Montagem unitizador 
 // ------------------------------ 
  If IntWms(SH6->H6_PRODUTO)
     If ! Empty(cIdUnitiz) .and. WmsArmUnit(SH6->H6_LOCAL)
	    oMntUniItem:ClearData()
	    oMntUniItem:oUnitiz:SetOrigem(cOrigem)
	    oMntUniItem:oUnitiz:SetArmazem(SH6->H6_LOCAL)
	    oMntUniItem:oUnitiz:SetEnder(cEndereco)
	    oMntUniItem:SetIdUnit(cIdUnitiz)
	    oMntUniItem:oUnitiz:SetStatus("1")           // Em Montagem
			
	    If ! oMntUniItem:oUnitiz:UniHasItem()
		   oMntUniItem:oUnitiz:SetTipUni(cTipoUnit)
		   oMntUniItem:oUnitiz:SetDatIni(dDataBase)
		   oMntUniItem:oUnitiz:SetHorIni(Time())
				
		   If ! oMntUniItem:oUnitiz:UpdStatus()
		      oMntUniItem:oUnitiz:SetDatFim(StoD(""))
		      oMntUniItem:oUnitiz:SetHorFim("")
		      oMntUniItem:SetPrdOri(SH6->H6_PRODUTO)
		      oMntUniItem:SetProduto(SH6->H6_PRODUTO)
		      oMntUniItem:SetLoteCtl(SH6->H6_LOTECTL)
		      oMntUniItem:SetNumLote(SH6->H6_NUMLOTE)
		      oMntUniItem:SetQuant(SH6->H6_QTDPROD)
					
		      If oMntUniItem:MntPrdUni()
			    // -- Caso operador tenha saído da montagem e não tenha
                // -- gerado Ordem de Serviço, altera o status para '2=Aguard. Ender'
                // ------------------------------------------------------------------
			     If oMntUniItem:oUnitiz:GetStatus() == "1"
				    oMntUniItem:oUnitiz:SetStatus("2")    // Aguardando Endereçamento
							
				    If ! oMntUniItem:oUnitiz:UpdStatus()
					   lRet := .F.
				    EndIf
			     EndIf
		      EndIf
					
		      If lRet .and. oMntUniItem:oUnitiz:GetStatus() == "3"
			     lRet := .F.
		      EndIf
					
		     // -- Deve validar se o unitizador possui itens
             // --------------------------------------------
		      If lRet .and. !oMntUniItem:oUnitiz:UniHasItem()
			     lRet := .F.
		      EndIf
					
		      lRet := WMSV086END({cIdUnitiz})
		   EndIf
	    EndIf
     EndIf
  EndIf

  oMntUniItem:Destroy()

 // -- Executar o serviço do Unitizador
 // ----------------------------------- 
  If ! Empty(cIdUnitiz) .and. lRet
	 U_ExecuteSrv(cIdUnitiz, cEndDest)

	 If ! Empty(cDocumento)
		dbSelectArea("D12")
		D12->(dbSetOrder(5))
		D12->(dbSeek(FWxFilial("D12") + cDocumento))
		
        While ! D12->(Eof()) .and. FWxFilial("D12") + cDocumento == D12->(D12_FILIAL + D12_DOC)
		  If D12->D12_STATUS == "4"
	         U_FinalzD12(Recno())
			 
             Exit
		  EndIf
		
          D12->(dbSkip())
		EndDo
	 EndIf
  EndIf

  FWRestArea(aArea)   
Return
