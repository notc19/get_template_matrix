#!/bin/bash

export PATH=$(cd `dirname $0` && pwd)/lib:${PATH}

TEMPLATE=$1



len=$(xidel --xpath "//pathway_template/@length" $TEMPLATE)

trap "rm -f $TEMPLATE.and $TEMPLATE.tmp* $TEMPLATE.nnp $TEMPLATE.*.andp" EXIT

xmlstarlet ed -d "//component[@id=0 or @id=${len}]/db_components/db_component" $TEMPLATE > $TEMPLATE.tmp
xmlstarlet ed -L -d "//component[@id=0 or @id=${len}]/syn_components/syn_component" $TEMPLATE.tmp

(
    # Печатаем названия колонок
    xidel --output-node-format=xml --xpath "//component[@id=${len}]/db_components/db_component | //component[@id=${len}]/syn_components/syn_component" $TEMPLATE > $TEMPLATE.tmp.$len.xml
    (cat $TEMPLATE.tmp.$len.xml) | \
       while read s1
         do
           if [[ "$s1" =~ ^\<db_ ]]; then
               name1=$(echo "$s1" | xidel --xpath '//db_component/@id' - )
               name1=${name1#*=}
           else
               name1=$(echo "$s1" | xidel --xpath '//syn_component/@name' - )
               name1=${name1#*=}
           fi
           echo -n "    $name1"
         done
    echo ""
    
    
    xidel --output-node-format=xml --xpath "//component[@id=0]/db_components/db_component | //component[@id=0]/syn_components/syn_component" $TEMPLATE > $TEMPLATE.tmp.0.xml
    COUNT=$(wc -l < $TEMPLATE.tmp.0.xml)
    if [ $COUNT -gt 100 ]; then
      if [ ! -e $TEMPLATE.and ]; then
        ANDVisio_cli -p $TEMPLATE -o $TEMPLATE.and >/dev/null 2>&1
      fi
      cat $TEMPLATE.and  | grep -v "<attribute" | grep -v "<sentence" | grep -v "<el" | grep -v "<synonym" | grep -v "</attribute" | grep -v "</sentence" | grep -v "</el" | grep -v "</synonym"> $TEMPLATE.tmp.small
      rm  $TEMPLATE.and
      xidel --xpath "//vertex[@level=0][@componenttype>1]/@id" $TEMPLATE.tmp.small > $TEMPLATE.tmp.id.txt
      xidel --xpath "//edge/@from_id | //edge/@to_id" $TEMPLATE.tmp.small | sort -u -n > $TEMPLATE.tmp.eid.txt
      awk 'NR==FNR { lines[$0]=1; next } $0 in lines' $TEMPLATE.tmp.id.txt $TEMPLATE.tmp.eid.txt | sort -n > $TEMPLATE.tmp.input_ids.txt
    
      ids=$(readarray -t ARRAY < $TEMPLATE.tmp.input_ids.txt; IFS='|'; echo "${ARRAY[*]}")
      xidel --xpath "//vertex[matches(@id, '^($ids)$')]" --output-format=xml $TEMPLATE.tmp.small > $TEMPLATE.tmp.input_vertices.xml
      rm $TEMPLATE.tmp.small
      cat $TEMPLATE.tmp.input_vertices.xml | grep '<vertex' | sed 's/<vertex/<syn_component/; s+>+/>+' > $TEMPLATE.tmp.0.xml
    fi
    
    
    cat $TEMPLATE.tmp.0.xml | parallel get_parallel_row "{}" $len $TEMPLATE

) > $TEMPLATE.result.tsv 

#########################################################################################################################
exit
(cat $TEMPLATE.tmp.0.xml) | \
while read s0
   do
      cat $TEMPLATE.tmp > $TEMPLATE.tmp0
      if [[ "$s0" =~ ^\<db_ ]]; then
          xmlstarlet ed -L -s "//component[@id=0]/db_components" -t elem -n START  $TEMPLATE.tmp0
          name0=$(echo "$s0" | xidel --xpath '//db_component/@id' - )
          name0=${name0#*=}
      else
          xmlstarlet ed -L -s "//component[@id=0]/syn_components" -t elem -n START  $TEMPLATE.tmp0
          name0=$(echo "$s0" | xidel --xpath '//syn_component/@name' - )
          name0=${name0#*=}
     fi
     echo -n "$name0"
     sed -i 's|<START/>|'"$s0"'|' $TEMPLATE.tmp0

     (cat $TEMPLATE.tmp.$len.xml) | \
       while read s1
         do
           #echo $s0
           #echo $s1
           #echo ""
           cat $TEMPLATE.tmp0 > $TEMPLATE.andp

           if [[ "$s1" =~ ^\<db_ ]]; then
               xmlstarlet ed -L -s "//component[@id=${len}]/db_components" -t elem -n STOP  $TEMPLATE.andp
               name1=$(echo "$s1" | xidel --xpath '//db_component/@id' - )
               name1=${name1#*=}
           else
               xmlstarlet ed -L -s "//component[@id=${len}]/syn_components" -t elem -n STOP  $TEMPLATE.andp
               name1=$(echo "$s1" | xidel --xpath '//syn_component/@name' - )
               name1=${name1#*=}
           fi
           #echo "$name0 $name1"
           sed -i 's|<STOP/>|'"$s1"'|' $TEMPLATE.andp


           while [ ! -e $TEMPLATE.nnp ]
           do
              ANDVisio_cli -p $TEMPLATE.andp -o $TEMPLATE.nnp >/dev/null 2>&1
           done

           count=$(grep -Ec '\->|--' $TEMPLATE.nnp | awk '{ if($1>0){$1=1}; print $1;}') #'

           echo -n "    $count"

           rm -f $TEMPLATE.nnp $TEMPLATE.andp
           #exit
         done
      echo ""
      #exit
   done
) > $TEMPLATE.result.tsv
