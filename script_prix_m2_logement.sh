#/bin/bash -xv

url="http://api.cquest.org/dvf?"

# vérifier si la commande jq est bien installé
sudo apt-get install jq htop -y -qq > /dev/null


#variable couleur
noir='\e[0;30m'
gris='\e[1;30m' 
rougefonce='\e[0;31m' 
rose='\e[1;31m' 
vertfonce='\e[0;32m' 
vertclair='\e[1;32m' 
orange='\e[0;33m' 
jaune='\e[1;33m' 
bleufonce='\e[0;34m' 
bleuclair='\e[1;34m' 
violetfonce='\e[0;35m' 
violetclair='\e[1;35m' 
cyanfonce='\e[0;36m' 
cyanclair='\e[1;36m' 
grisclair='\e[0;37m' 
blanc='\e[1;37m' 
neutre='\e[0;m'


# Objectif : télécharge le fichier json si il n'existe pas
# paramètre 1 : type_de_recherche [ "commune" | "section" |  "distance"]
# paramètre 2 : valeur_de_recherche [ ex : "59650" | "89304000ZB" | "48.85" (latitude) ]
# [OPTIONEL] paramètre 3 : valeur_de_recherche [ "longitude" ]
function telechargement_fichier(){

	if [ $# -lt 2 ]
	then
		echo "La fonction nécessite au moins deux paramètres"
		exit 1
	fi

	nom_fichier=${2}-data.json

	if [ $1 == "distance" ]
	then
		if [ $# -lt 3 ]
		then 
			echo "la fonction nécessite 3 paramètres"
			exit 1
		fi
		nom_fichier=lat${2}lon${3}-data.json
	fi
 
	echo "Téléchargement des informations en cours..."
	case $1 in 
		"commune")
			wget -q ${url}"code_postal="${2} -O ${nom_fichier}
			;;
		"section")
			wget -q ${url}"section="${2} -O ${nom_fichier}
			;;
		"distance")
			wget -q ${url}"lat="${2}"&lon="${3} -O ${nom_fichier}
			;;
		*)
			echo "Le 1er paramètre à saisir n'est pas conforme."
			;;
	esac 
	
} 

# Objectif : recherche et télécharge le fichier json selon le code postal et le type de logement ["Appartement" ou "Maison"]
function recherche_code_postal_deux_parametres(){
	read -p "Saisir le code postal : " code_postal	
	while [ "${#code_postal}" -ne 5 ]
	do
		echo "Erreur de saisie, un code postal prend 5 caractères"
		read -p "Saisir le code postal : " code_postal	
	done

	case $1 in
		"Appartement" | "Maison" )
			echo "Téléchargement des informations en cours..."
			wget -q ${url}"code_postal="${code_postal}"&type_local=${1}" -O ${code_postal}-${1}-data.json
			nom_fichier=${code_postal}-${1}-data.json
			;;
		*)
			echo "Erreur de saisie"
			;;
	esac
}

function recherche_code_postal(){
	read -p "Saisir le code postal : " code_postal	
	while [ "${#code_postal}" -ne 5 ]
	do
		echo "Erreur de saisie, un code postal prend 5 caractères"
		read -p "Saisir le code postal : " code_postal	
	done
	
	if [ ! -e "./$code_postal-data.json" ] ; then
		telechargement_fichier "commune" ${code_postal}
	else
		echo "chargement du fichier ${code_postal}"-data.json" existant..."
		nom_fichier=${code_postal}-data.json
	fi
}

function recherche_section(){ 
	read -p "Saisir la section : " num_section
	while [ "${#num_section}" -ne 10 ]
	do
		echo "Erreur de saisie, une section cadastrale prend 10 caractères"
		read -p "Saisir la section : " num_section
	done

	if [ ! -e  "./${num_section}-data.json" ] ; then
		telechargement_fichier "section" ${num_section}
	else
		echo "chargement du fichier ${num_section}"-data.json" existant..."
		nom_fichier=${num_section}-data.json
	fi
}

function recherche_distance(){
	read -p "Saisir la latitude : " latitude
	read -p "Saisir la longitude : " longitude
	if [ ! -e "./lat${latitude}lon${longitude}-data.json" ] ; then
		telechargement_fichier "distance" ${latitude} ${longitude}
	else
		echo "chargement du fichier "lon="${latitude}"lat="${longitude}"-data.json" existant..."
		nom_fichier=lat${latitude}lon${longitude}-data.json
	fi
}

# Récupère et affiche la liste des cadastres selon le code postal
function liste_sections_cadastres(){
	recherche_code_postal

	if [ ! -f liste_section_${code_postal}.txt ]
	then
		cat ${nom_fichier} | jq '.resultats | .[] |
											{"numero_plan","voie"} | 
											select ("numero_plan" != null and "voie" != null)' | 
											jq '@text' > liste_section_${code_postal}.txt

		sed -i 's/\\/ /g' liste_section_${code_postal}.txt
		sed -i 's/"/ /g' liste_section_${code_postal}.txt
		sed -i 's/{/ /g' liste_section_${code_postal}.txt
		sed -i 's/}/ /g' liste_section_${code_postal}.txt
	fi
	echo "Chargement de la liste des sections pour le code postal : ${code_postal}"
	sleep 2
	cat liste_section_${code_postal}.txt
	echo 
	echo "Exemple : Pour le numero_plan : 59360000AE0400, le cadastre est 59360000AE  (10 premiers caractères)"

}

# Objectif : retourne le nombre de résultats d'un fichier json
function nombre_resultats(){
	nb_resultats=$(cat ${nom_fichier} | jq '.nb_resultats')
	if  [ ${nb_resultats} -eq 0 ] 
	then
		echo "0"
	else
		echo "${nb_resultats}"
	fi
}

function calcul_prix_m_carre(){
		
	if [ $(nombre_resultats) == 0 ]
	then	
		echo "Aucun résultat dans ce fichier"
		rm ${nom_fichier}
		exit 1
	fi
	
	cat ${nom_fichier} | jq '.resultats|.[]|
										{"valeur_fonciere","surface_terrain","surface_relle_bati"}| 
										select(."valeur_fonciere" > 0 and ."surface_terrain" > 0)|
										.valeur_fonciere / .surface_terrain |floor ' > fichier_tmp
	
	nombre_lignes=$( cat fichier_tmp | wc -l )
	somme=$( awk '{total+=$1}END{print total}' fichier_tmp )
	
	#  ${variable%.*} pour convertir la variable float en integer
	moyenne=$((${somme%.*}/${nombre_lignes}))
	
	echo "Résultat du fichier ${nom_fichier}"
	echo -e "${vertfonce}${1},le prix du mètre carré est de ${rougefonce}${moyenne} € ${neutre}"
	
	# sudo rm fichier_tmp
}

function calcul_prix_m_carre_prox_geographique(){

	nb_resultats=$(cat ${nom_fichier} | jq '.features') 

	if [  "${nb_resultats}" == '[]' ]
	then
		echo "Aucun résultat dans ce fichier"
		rm ${nom_fichier}
		exit 1
	fi

	cat ${nom_fichier} | jq '.features |.[] | .properties |
												{"valeur_fonciere","surface_terrain","surface_relle_bati"}|
												select(."valeur_fonciere" > 0 and ."surface_terrain" > 0)|
												.valeur_fonciere / .surface_terrain |floor ' > fichier_tmp

	nombre_lignes=$( cat fichier_tmp | wc -l )
	somme=$( awk '{total+=$1}END{print total}' fichier_tmp )
	
	#  ${variable%.*} pour convertir la variable float en integer
	moyenne=$((${somme%.*}/${nombre_lignes}))
	
	echo "Résultat du fichier ${nom_fichier}"
	echo -e "${vertfonce}${1},le prix du mètre carré est de ${rougefonce}${moyenne} € ${neutre}"

}

function menu_recherche() {

	echo -e ${orange} ""
	echo "          ######  #     # #######"
	echo "          #     # #     # #"       
	echo "          #     # #     # #"      
	echo "          #     # #     # #####"  
	echo "          #     #  #   #  #"       
	echo "          #     #   # #   #"       
	echo "          ######     #    #"   	 
	echo "Menu"
	echo "---------------------------------------------"
	echo "1 - Recherche par code postal"
	echo "2 - Recherche par section cadastrale"
	echo "3 - Recherche par proximité géographique"
	echo "4 - Quitter"
	echo "---------------------------------------------"
	echo
	echo -e ${neutre}"Veuillez saisir votre choix : "
	read choix
}

function menu_code_postal() {

	echo -e ${orange}"Type de logement concerné : "
	echo "---------------------------------------------"
	echo "1 - Recherche Complet"
	echo "2 - Recherche par Appartement"
	echo "3 - Recherche par Maison"
	echo "4 - Retour"
	echo "---------------------------------------------"
	echo
	echo -e ${neutre}"Veuillez saisir votre choix : "
	read choix_menu_code_postal
}

function menu_section() {
	echo -e ${orange}"Menu"
	echo "---------------------------------------------"
	echo "1 - Saisir section cadastrale"
	echo "2 - Lister sections par code postal"
	echo "3 - Retour"
	echo "---------------------------------------------"
	echo
	echo -e ${neutre}"Veuillez saisir votre choix : "
	read choix_menu_section
}


function menu_principal() {
	continuation=0
	while [  ${continuation} -eq 0 ]
	do
		retour=0
		menu_recherche
		case ${choix} in 
			1)
				continue_menu_code_postal=0 
				menu_code_postal
				while [ ${continue_menu_code_postal} -eq 0 ]
				do
					case ${choix_menu_code_postal} in
						1)
							recherche_code_postal 
							calcul_prix_m_carre "Pour le code postal : ${code_postal}" 
							break
							;;
						2)
							recherche_code_postal_deux_parametres "Appartement"
							calcul_prix_m_carre "Pour les appartements du ${code_postal}" 
							break
							;;
						3)
							recherche_code_postal_deux_parametres "Maison"
							calcul_prix_m_carre "Pour les maisons du ${code_postal}" 	
							break
							;;
						4)
							retour=1
							break 
							;;
						*)
							echo "Veuillez saisir un numéro valide !"
							menu_code_postal
							;;
					esac

				done
				;;
			2)
				continue_menu_section=0 
				menu_section
				while [ ${continue_menu_section} -eq 0 ]
				do
					case ${choix_menu_section} in
						1)
							recherche_section
							calcul_prix_m_carre "Pour la section : ${num_section}"
							break
							;;
						2)
							liste_sections_cadastres
							menu_section
							;;
						3)
							retour=1
							break
							;;
						*)
							echo "Veuillez saisir un numéro valide !"
							menu_code_postal
							;;
					esac

				done	
				;;				
			3)
				recherche_distance
				calcul_prix_m_carre_prox_geographique "Pour la position géographique : (lat:${latitude},long:${longitude})"
				;;
			4)
				echo "A bientôt ! "
				continuation=1
				exit 1
				;;
			*)
				echo "Veuillez saisir un numéro valide !"
				retour=1
				;;
		esac

		if  [  ${retour}  -eq 0 ]; then
			read -p "Voulez vous continuez ? [O/n] " continuer 

			if ! [ ${continuer} == "O" -o ${continuer} == "o" -o ${continuer} == "Oui" -o ${continuer} == "oui"  ]
			then
				continuation=1
				exit 1
			fi
		fi
	done
}


menu_principal



