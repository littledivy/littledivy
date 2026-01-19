#import "./shim/html.typ": *

#set document(
  title: "404 not found",
  description: "Divy's personal page. Software writeups and more",
)

#show: html-shim

#nav-bar()

#title()

did you get lost? #html.elem("a", attrs: (href: "/"), [go to root])
