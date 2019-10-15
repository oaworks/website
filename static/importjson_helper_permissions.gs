var indexSheetName = 'Index'
function onOpen(){
  var ui = SpreadsheetApp.getUi();
  ui.createMenu('ImportJSON')
  .addItem('Run All', 'runImportJSON')
  .addItem('Run Active Cell', 'runImportJSONSingle')
  .addToUi();
}

function getIndexSheet(){
var SS = SpreadsheetApp.getActive();
var sheet = SS.getSheetByName(indexSheetName);
if(!sheet){
sheet = SS.insertSheet(indexSheetName)
}
return sheet
}
function runImportJSON(){
  var SS = SpreadsheetApp.getActive();
  var indexSheet = getIndexSheet();
  var indexData = indexSheet.getDataRange().getValues();
  var activeSheet = SS.getActiveSheet();
  var formulas = activeSheet.getDataRange().getFormulas();
  var formulasIndex = [];
  for(var i = 0; i < formulas.length; i++){
    for(var j = 0; j < formulas[0].length; j++){
      if(formulas[i][j] != ''){
        if(formulas[i][j].toString().match('ImportJSON')){
          formulasIndex.push([activeSheet.getName(),i+1,j+1,'__'+formulas[i][j],''])
        }
      }

    }

  }

 if(formulasIndex.length){
  for(var j = 0; j< formulasIndex.length; j++){
    var found = false;
    var foundIndex = 0;
    for(var i = 0; i < indexData.length;i++){
      if(indexData[i][0] == formulasIndex[j][0] && indexData[i][1] == formulasIndex[j][1]&& indexData[i][2] == formulasIndex[j][2]){
        found = true;
        foundIndex = i;
        break;
      }
    }
    if(found){
      indexData[foundIndex] = formulasIndex[j];
    }else{
      indexData.push(formulasIndex[j]);
    }
  }
  if(indexData.length){
    if(indexData[0][0] == ''){
      indexData.shift();
    }
    if(indexData.length){
     indexData =  jaggedToRegular(indexData)
      indexSheet.getRange(1,1,indexData.length, indexData[0].length).setValues(indexData)
    }
  }
    var namedRanges = SpreadsheetApp.getActive().getNamedRanges().map(function(item){
    return [item, item.getName(), item.getRange()]
   });
  setData(indexData,activeSheet,indexSheet,namedRanges);

  }
}

function runImportJSONSingle(){
   var SS = SpreadsheetApp.getActive();
  var indexSheet = getIndexSheet();
  var indexData = indexSheet.getDataRange().getValues();
  var activeSheet = SS.getActiveSheet();
  var formula = activeSheet.getActiveCell().getFormula();
  var formulasIndex = [];
  var row = activeSheet.getActiveCell().getRow();
  var col = activeSheet.getActiveCell().getColumn();
  if(formula && formula.match('ImportJSON')){

    formulasIndex = [[activeSheet.getName(),row,col,'__'+formula,'']]
  }else{
    if(indexData.length){
      for(var i = 0; i < indexData.length; i++){
        if(indexData[i][0] == activeSheet.getName() && indexData[i][1] == row && indexData[i][2] == col){
          formulasIndex = [indexData[i]]
          break;
        }
      }
    }
  }

 if(formulasIndex.length){
   for(var j = 0; j< formulasIndex.length; j++){
     var found = false;
     var foundIndex = 0;
     for(var i = 0; i < indexData.length;i++){
       if(indexData[i][0] == formulasIndex[j][0] && indexData[i][1] == formulasIndex[j][1]&& indexData[i][2] == formulasIndex[j][2]){
         found = true;
         foundIndex = i;
         break;
       }
     }
     if(found){
       indexData[foundIndex] = formulasIndex[j];
     }else{
       indexData.push(formulasIndex[j]);
     }
   }
   if(indexData.length){
     if(indexData[0][0] == ''){
       indexData.shift();
     }
     if(indexData.length){
       indexData =  jaggedToRegular(indexData)
       indexSheet.getRange(1,1,indexData.length, indexData[0].length).setValues(indexData)
     }
   }
   indexData = indexData.map(function(item){
     if(item[0] == activeSheet.getName() && item[1] == formulasIndex[0][1] && item[2] == formulasIndex[0][2]){

     }else{
         item[0] = ''
     }
     return item
   })
   var namedRanges = SpreadsheetApp.getActive().getNamedRanges().map(function(item){
    return [item, item.getName(), item.getRange()]
   });
   setData(indexData,activeSheet,indexSheet,namedRanges);
   }


}


function setData(indexData,activeSheet,indexSheet,namedRanges){

  if(indexData.length){


      indexData.map(function(item,index){
      if(item[0]){
        var name = item[3].replace('__','');

        var formula = name.match(/ImportJSON\((.*)\)/gm);

        var replaced = formula[0].replace("ImportJSON(",'')
        namedRanges.map(function(rangeItem){
        if(replaced.match('"&'+rangeItem[1]+',')){
                replaced = replaced.replace('"&'+rangeItem[1]+',',rangeItem[2].getValue()+'",')

        }

        })
        var searchParam = replaced.match(/"&([A-Z])(\d+)(\&)/gm);
        var searchParam2 = replaced.match(/"&([A-Z])(\d+)/gm);

        var searchParam3 = replaced.match(/"&\$([A-Z])(\d+)(\&)"/gm);
        if(searchParam){
          searchParam = searchParam[0].replace('"&','').replace(',"','').replace('&','')
          var param = activeSheet.getRange(searchParam).getValue();
          if(param != ''){
            replaced = replaced.replace(/"&([A-Z])(\d+)(\&)/gm,param).replace('))','')
            var commaCount = replaced.split(',').length-1;
            if(commaCount == 2){
              var split =replaced.split(',').map(function(param){
                return param.replace(/"/g,'').trim();
              })
              }else{
                replaced=replaced.replace(',,','--,--,');
                var split =replaced.split('--,').map(function(param){
                  return param.replace(/"/g,'').trim();
                })
              }
            split[split.length -1] = split[split.length -1].replace('),),','').replace(')','');
            var data = ImportJSON(split[0], split[1], split[2]);
            //ArrayFormula('Sheet1'!A:A)//
            name = name.replace(/ImportJSON\((.*?)\)/gm,"ArrayFormula('"+indexSheetName+"'!E"+(index+1)+":"+toColumnName(4+data[0].length)+(index+1)+")");
            indexSheet.getRange( (index+1),5,data.length,data[0].length).setValues(data);
            activeSheet.getRange(item[1], item[2]).setValue(name)


          }
        }else if(searchParam2){
        searchParam2 = searchParam2[0].replace('"&','').replace(',"','')
        var param = activeSheet.getRange(searchParam2).getValue();
          if(param != ''){
            replaced = replaced.replace(/"&([A-Z])(\d+)/gm,param+'"').replace('))','')
            var split =replaced.split('","').map(function(param){
              return param.replace(/"/g,'').trim();
            })

            split[split.length -1] = split[split.length -1].replace('),),','').replace(')','');
            var data = ImportJSON(split[0], split[1], split[2]);
            //ArrayFormula('Sheet1'!A:A)//
            name = name.replace(/ImportJSON\((.*?)\)/gm,"ArrayFormula('"+indexSheetName+"'!E"+(index+1)+":"+toColumnName(4+data[0].length)+(index+1)+")");
            indexSheet.getRange( (index+1),5,data.length,data[0].length).setValues(data);
            activeSheet.getRange(item[1], item[2]).setValue(name)

          }
        }else if(searchParam3){
           var range = searchParam3[0].replace('"&$','').replace('&"','')
           var param = activeSheet.getRange(range).getValue();
          if(param != ''){
            replaced = replaced.replace(/"&\$([A-Z])(\d+)(\&)"/gm,param+'"').replace('))','')
            var split =replaced.split('","').map(function(param){
              return param.replace(/"/g,'').trim();
            })

            split[split.length -1] = split[split.length -1].replace('),),','').replace(')','');
            var data = ImportJSON(split[0], split[1], split[2]);
            //ArrayFormula('Sheet1'!A:A)//
            data = data[0] ? data : [['']]
            name = name.replace(/ImportJSON\((.*?)\)/gm,"ArrayFormula('"+indexSheetName+"'!E"+(index+1)+":"+toColumnName(4+data[0].length)+(index+1)+")");
            indexSheet.getRange( (index+1),5,data.length,data[0].length).setValues(data);
            activeSheet.getRange(item[1], item[2]).setValue(name)

          }
        }else{
           name = name.replace('=ImportJSON(','');
          var split =name.replace('", "','","').split('","').map(function(param){
            return param.replace(/"/g,'').trim();
          })

          split[split.length -1] = split[split.length -1].replace('),),','').replace(')','');
          var data = ImportJSON(split[0], split[1], split[2]);
          activeSheet.getRange(item[1], item[2], data.length, data[0].length).setValues(data)

        }
      }
      });


  }

}

function toColumnName(num) {
  for (var ret = '', a = 1, b = 26; (num -= a) >= 0; a = b, b *= 26) {
    ret = String.fromCharCode(parseInt((num % b) / a) + 65) + ret;
  }
  return ret;
}


function jaggedToRegular(arr){
var max = arr.reduce(function(a, b) {
  return Math.max(a, b.length)
}, 0);
arr = arr.map(function(itm) {
  itm.length = max;
  return itm
});

return arr;
}
