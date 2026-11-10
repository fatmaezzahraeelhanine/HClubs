import React from 'react'
import { createRoot } from 'react-dom/client'
import { AuthProvider } from './context/AuthContext'
import { DataProvider } from './context/DataContext'
import App from './App'
import './styles.css'

createRoot(document.getElementById('root')).render(
  <React.StrictMode><AuthProvider><DataProvider><App /></DataProvider></AuthProvider></React.StrictMode>,
)
