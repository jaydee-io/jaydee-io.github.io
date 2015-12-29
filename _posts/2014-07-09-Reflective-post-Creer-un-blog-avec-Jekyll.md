---
layout: post
title: "Reflective post : Créer un blog avec Jekyll"
---

Créer son blog avec Jekyll.

# Installer les outils

Primo installer Ruby. Sous mon Ubuntu 14.04, il a aussi fallu que j'installe le package `ruby-dev` pour pouvoir installer Jekyll.
A l'exécution, Jekyll nécéssite aussi `node.js`.

{% highlight bash %}
$ sudo apt-get install ruby ruby-dev nodejs
{% endhighlight %}

Ensuite installer Jekyll. Dans mon cas, le blog est hébergé sur GitHub Pages.
Pour assurer la compatibilité avec GitHub, il est préférable d'installer le gem `github-pages` qui se charge d'installer Jekyll avec toutes les dépendances nécessaires.
Une mise à jour récente des gems permet aussi d'éviter de se retrouver avec un vieux Jekyll qui supporterai pas encore l'extension Saas/SCSS (genre une version 1.5.1).

{% highlight bash %}
$ sudo gem install github-pages
$ sudo gem update
{% endhighlight %}

Jekyll est installé.

# Initialiser le blog

Y a plus qu'a créer son blog :

{% highlight bash %}
$ jekyll new _dossier de mon blog_
{% endhighlight %}

Votre blog est créé avec un thème par défaut et un post d'exemple.

# Hébergement chez GitHub Pages

GitHub propose un service d'hébergement de site web basé sur Jekyll.
Pour créer un blog personnel, il suffit de créer un repository nommé `username.github.io` (_username_ correspondant, bien évidement, à votre nom d'utilisateur GitHub).
Il suffit ensuite de peupler ce repository avec le contenu de votre site Jekyll.
GitHub Pages détecte automatiquement qu'il s'agit d'un projet Jekyll et se charge de générer le site.
Donc pas besoin de committer le répertoire `_site`.

Votre site est alors accessible depuis l'adresse `http://_username_.github.io`.
Si vous disposez d'un nom de domaine perso que vous voulez rediriger vers `http://_username_.github.io`, il est nécessaire d'ajouter à la racine du projet un fichier `CNAME` contenant juste l'adresse perso de votre blog. 

Dans mon cas :
{% highlight text %}
jaydee.io
{% endhighlight %}
 
Pour mettre à jour votre blog, il suffira simplement de committer vos nouveaux articles et de les pusher vers GitHub !!!

# Nom de domaine chez _Gandi.net_
Si votre nom de domaine perso est enregistré chez _Gandi.net_, voici la procédure à suivre pour le rediriger vers votre site GitHub Pages.

Tout d'abord il est nécessaire de récupérer l'adresse IP associée à votre site  `http://_username_.github.io`.
Pour cela, rien de plus simple, il suffit d'utiliser la commande `dig`.

{% highlight bash %}
$ dig username.github.io +nostats +nocomments +nocmd

; <<>> DiG 9.9.5-3-Ubuntu <<>> username.github.io +nostats +nocomments +nocmd
;; global options: +cmd
;username.github.io.         IN  A
username.github.io.     3565 IN  CNAME github.map.fastly.net.
github.map.fastly.net.  980  IN  A     aaa.bbb.ccc.ddd
{% endhighlight %}

Ensuite, sur l'interface d'administration de _Gandi.net_ <http://www.gandi.net/admin> cliquez sur le nom de domaine à rediriger vers votre blog.
Ensuite _Editer la zone_ (en bas à droite de l'interface).
_Gandi.net_ ne permet pas de modifier le fichier de zone par défaut, il faut donc le copier en cliquant sur _Dupliquer la zone_.
De même, un fichier de zone contient plusieurs versions et la version en cours d'utilisation ne peut pas être modifiée.
Il faut donc la dupliquer en cliquant sur _Créer une nouvelle version_ et l'activer en cliquant _Activer cette version_.

Après avoir valider, la version n°1 est alors disponible pour modification.
L'ensemble des lignes de type _CNAME_ peuvent supprimées.
Ensuite il faut modifier la ligne de type _A_.
Dans le champs _Valeur_, il faut préciser l'adresse IP _aaa.bbb.ccc.ddd_ obtenue précédement avec `dig`.

Enfin, dans le champs _Nom_, il faut renseigner le sous-domaine que vous souhaitez associer à votre blog :

* Pour un sous domaine particulier (ex. : _blog.mondomaine.fr_, _www.mondomaine.fr_, ...), mettez directement le nom
* Pour rediriger le domaine complet (ex. : _mondomaine.fr_), renseignez _@_
* Pour rediriger tous les sous-domaines (ex. : _*.mondomaine.fr_), renseignez _*_.

Une fois validée, activer la version n°1... C'est bon votre nom de domaine est redirigé !!!
