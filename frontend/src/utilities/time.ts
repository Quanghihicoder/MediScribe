export const getMinutes = (seconds: number) => {
    return Math.floor(seconds / 60);
}

export const getRemainingSeconds = (seconds: number) => {
    return seconds % 60
}

export const formatTimeInMinutes = (seconds: number) => {
    const minutes = getMinutes(seconds)
    const remaining = getRemainingSeconds(seconds)
    
    return (minutes >= 10 ? minutes.toString() : "0" + minutes.toString()) + ":" + (remaining >= 10 ? remaining.toString() : "0"+ remaining.toString())
}