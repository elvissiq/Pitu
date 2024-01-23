#INCLUDE "PROTHEUS.CH"

User Function WV084AUT()
Local cOrigem := PARAMIXB[1]
Local cIdUnit := PARAMIXB[3]
Local cSeekZZZ := ""
Local nTamPrd := FwTamSX3("D0S_CODPRO")[1]
Local nTamLot := FwTamSX3("D0S_LOTECT")[1]
Local nTamSub := FwTamSX3("D0S_NUMLOT")[1]
Local aItensUni := {}
Local aItem := {}

    cSeekZZZ := FWxFilial("ZZZ")+cOrigem+cIdUnit
    ZZZ->(DbSetOrder(1))
    ZZZ->(DbSeek(cSeekZZZ))

    While !ZZZ->(Eof()) .And. ZZZ->ZZZ_FILIAL+ZZZ->ZZZ_ORIGEM+ZZZ->ZZZ_IDUNIT == cSeekZZZ
    
        AAdd(aItem,PadR(ZZZ->ZZZ_PRDORI ,nTamPrd))
        AAdd(aItem,PadR(ZZZ->ZZZ_PRODUT ,nTamPrd))
        AAdd(aItem,PadR(ZZZ->ZZZ_LOTECTL,nTamLot))
        AAdd(aItem,PadR(ZZZ->ZZZ_SUBLOT ,nTamSub))
        AAdd(aItem,ZZZ->ZZZ_QUANT)
        AAdd(aItensUni,aItem)
        
    ZZZ->(DbSkip())
    EndDo

Return aItensUni
