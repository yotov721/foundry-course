// Add this check at the beginning of your initProvider function
const initProvider = async () => {
  // Only initialize in browser environments
  if (typeof window === 'undefined' || typeof indexedDB === 'undefined') {
    return null;
  }
  
  // Rest of your initialization code
  // ...
}